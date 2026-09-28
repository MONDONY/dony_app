import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// File Hive des étapes pas encore reçues par le back : scans faits hors
/// ligne, et validations annulables de l'onglet Suivi (entrées avec une
/// échéance `notBefore`, envoyées par [sendScheduled] ou, si le process est
/// mort entre-temps, par [syncAll] une fois l'échéance passée).
///
/// Une entrée n'est envoyée que par un seul appel à la fois : elle est
/// réservée (clé dans [_inFlight]) avant tout appel réseau et libérée après.
class OfflineSyncService {
  final HiveService _hive;
  final TrackingRepository _repository;
  final ErrorReportingService? _errorReporter;
  final DateTime Function() _now;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _syncing = false;

  /// Clés en cours d'envoi dans ce process. Perdues avec lui : au
  /// redémarrage, l'entrée encore en file est rejouée.
  final _inFlight = <Object?>{};

  /// Relance [syncAll] à la prochaine échéance d'une entrée pas encore due.
  Timer? _wakeUp;

  OfflineSyncService(
    this._hive,
    this._repository, [
    this._errorReporter,
    this._now = DateTime.now,
  ]);

  void startListening() {
    // Le process a pu mourir avec des étapes en file (validation en attente
    // comprise) : elles repartent dès le démarrage, sans attendre un
    // changement de réseau.
    unawaited(syncAll());
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) syncAll();
    });
  }

  void dispose() {
    _sub?.cancel();
    _wakeUp?.cancel();
  }

  /// Scans en attente de réseau. Une validation encore annulable ou en
  /// cours d'envoi n'en fait pas partie.
  int get pendingCount => _countWaiting((_) => true);

  /// Scans en attente qui concernent l'un de ces colis.
  int pendingCountFor(Set<String> bidIds) =>
      _countWaiting((raw) => bidIds.contains(raw['bidId']));

  int _countWaiting(bool Function(Map raw) test) {
    final box = _hive.offlineQueue;
    final now = _now();
    var count = 0;
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw == null || _inFlight.contains(key) || _notDue(raw, now)) {
        continue;
      }
      if (test(raw)) count++;
    }
    return count;
  }

  /// Notifie chaque ajout ou envoi d'un scan de la file.
  Listenable get queueChanges => _hive.offlineQueue.listenable();

  /// Met l'étape en file et rend sa clé. Avec [notBefore], [syncAll] ne
  /// l'envoie pas avant cette échéance (délai d'annulation de l'onglet
  /// Suivi) ; sans, elle part au prochain [syncAll].
  Future<int> queueScan({
    required String bidId,
    required String eventType,
    double? gpsLat,
    double? gpsLon,
    String? gpsLabel,
    String? photoPath,
    ScanMethod? scanMethod,
    DateTime? notBefore,
  }) {
    final entry = <String, dynamic>{
      'bidId': bidId,
      'eventType': eventType,
      'gpsLat': ?gpsLat,
      'gpsLon': ?gpsLon,
      'gpsLabel': ?gpsLabel,
      'photoPath': ?photoPath,
      // Absent des entrées mises en file avant la provenance : rien n'est
      // alors envoyé au back.
      'scanMethod': ?scanMethod?.wire,
      'offlineTimestamp': _now().toUtc().toIso8601String(),
      'notBefore': ?notBefore?.toUtc().toIso8601String(),
    };
    return _hive.offlineQueue.add(entry);
  }

  /// Retire l'entrée [key] de la file : elle ne partira pas (« Annuler »).
  Future<void> discard(int key) => _hive.offlineQueue.delete(key);

  /// Envoie tout de suite l'entrée [key], sans attendre son échéance, avec
  /// la [position] relevée entre-temps (écrite dans l'entrée avant l'envoi).
  ///
  /// Rend l'évènement créé, ou `null` quand l'entrée reste en file (réseau,
  /// 5xx, session expirée : son échéance est alors levée et [syncAll] la
  /// reprend), n'existe plus ou part déjà par [syncAll]. Un refus définitif
  /// du back la retire de la file et remonte.
  Future<TrackingEventModel?> sendScheduled(
    int key, {
    Future<ScanPosition?>? position,
  }) async {
    final raw = _hive.offlineQueue.get(key);
    // Réservée avant la moindre attente : un syncAll concurrent la saute.
    if (raw == null || !_inFlight.add(key)) return null;
    var entry = Map<String, dynamic>.from(raw);
    try {
      final at = await position;
      if (at != null) {
        entry = {
          ...entry,
          'gpsLat': at.lat,
          'gpsLon': at.lon,
          'gpsLabel': ?at.label,
        };
        // Écrite avant l'envoi : rejouée avec sa position si le process
        // meurt pendant l'appel.
        await _hive.offlineQueue.put(key, entry);
      }
      return await _send(key, entry, deferred: false);
    } catch (error, stackTrace) {
      if (isDefinitiveRejection(unwrapDioError(error))) rethrow;
      _reportUnexpected(error, stackTrace, failedCount: 1);
      // Libérée avant l'écriture : le bandeau rebâti par cette écriture la
      // compte déjà parmi les scans en attente.
      _inFlight.remove(key);
      if (_hive.offlineQueue.containsKey(key)) {
        await _hive.offlineQueue.put(key, entry..remove('notBefore'));
      }
      return null;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<void> syncAll() async {
    if (_syncing || _hive.offlineQueue.isEmpty) return;
    _syncing = true;
    _wakeUp?.cancel();
    DateTime? nextDue;
    var failedCount = 0;
    Object? lastError;
    StackTrace? lastStackTrace;
    try {
      final keys = _hive.offlineQueue.keys.toList();
      for (final key in keys) {
        final raw = _hive.offlineQueue.get(key);
        if (raw == null) continue;
        final notBefore = _notBefore(raw);
        if (notBefore != null && notBefore.isAfter(_now())) {
          // Encore annulable : l'onglet Suivi l'enverra lui-même, sinon on
          // repasse à l'échéance.
          if (nextDue == null || notBefore.isBefore(nextDue)) {
            nextDue = notBefore;
          }
          continue;
        }
        if (!_inFlight.add(key)) continue;
        try {
          await _send(key, Map<String, dynamic>.from(raw), deferred: true);
        } catch (error, stackTrace) {
          // Refus définitif : déjà retirée par _send.
          if (isDefinitiveRejection(unwrapDioError(error))) continue;
          // Panne réseau, délai, 5xx, session expirée : on garde l'entrée
          // pour la prochaine tentative.
          failedCount++;
          lastError = error;
          lastStackTrace = stackTrace;
        } finally {
          _inFlight.remove(key);
        }
      }
      if (failedCount > 0) {
        _reportUnexpected(lastError!, lastStackTrace, failedCount: failedCount);
      }
    } finally {
      _syncing = false;
      if (nextDue != null) {
        _wakeUp = Timer(nextDue.difference(_now()), () => unawaited(syncAll()));
      }
    }
  }

  /// Photo d'abord, puis l'étape ; l'entrée quitte la file au succès. Un
  /// refus définitif la retire aussi ; toute erreur remonte. [deferred] :
  /// envoi différé (hors ligne ou rejeu), daté de la mise en file.
  Future<TrackingEventModel> _send(
    Object? key,
    Map<String, dynamic> entry, {
    required bool deferred,
  }) async {
    final bidId = entry['bidId'] as String;
    try {
      String? photoKey;
      final photoPath = entry['photoPath'] as String?;
      if (photoPath != null) {
        photoKey = await _repository.uploadTrackingPhoto(bidId, photoPath);
      }
      final event = await _repository.postScan(
        bidId: bidId,
        eventType: entry['eventType'] as String,
        gpsLat: (entry['gpsLat'] as num?)?.toDouble(),
        gpsLon: (entry['gpsLon'] as num?)?.toDouble(),
        gpsLabel: entry['gpsLabel'] as String?,
        photoUrl: photoKey,
        scanMethod: ScanMethod.fromWire(entry['scanMethod']),
        offlineTimestamp: deferred
            ? DateTime.parse(entry['offlineTimestamp'] as String)
            : null,
      );
      await _hive.offlineQueue.delete(key);
      return event;
    } catch (error) {
      if (isDefinitiveRejection(unwrapDioError(error))) {
        // Le serveur a tranché (409 départ déjà scanné, 422, 404, 403) :
        // rejouer l'entrée à chaque retour du réseau ne changera rien et
        // gonflait Sentry côté back d'un 500 par tentative
        // (YADONY-BACK-STAGING-8, deux évènements à 8 s d'écart).
        await _hive.offlineQueue.delete(key);
      }
      rethrow;
    }
  }

  /// Signale à Sentry une erreur qui n'est pas une simple panne réseau.
  void _reportUnexpected(
    Object error,
    StackTrace? stackTrace, {
    required int failedCount,
  }) {
    if (error is DioException) return;
    unawaited(
      _errorReporter?.report(
        error,
        operation: 'tracking.offline_sync',
        stackTrace: stackTrace,
        context: {
          'feature': 'tracking',
          'channel': 'offline',
          'retry_count': failedCount,
        },
      ),
    );
  }

  static DateTime? _notBefore(Map raw) {
    final value = raw['notBefore'] as String?;
    return value == null ? null : DateTime.parse(value);
  }

  static bool _notDue(Map raw, DateTime now) =>
      _notBefore(raw)?.isAfter(now) ?? false;

  /// Vrai quand le back a refusé le scan pour une raison qui ne dépend pas
  /// du réseau ni du moment : la même requête échouerait à l'identique.
  static bool isDefinitiveRejection(AppException error) {
    return error is ConflictException ||
        error is ValidationException ||
        error is NotFoundException ||
        error is ForbiddenException;
  }
}
