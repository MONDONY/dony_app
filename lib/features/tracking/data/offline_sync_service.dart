import 'dart:async';
import 'dart:io' show FileSystemException;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/report_severity.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/scan_locator.dart';
import 'package:dony/features/tracking/data/scan_send_guard.dart';
import 'package:dony/features/tracking/data/tracking_photo_upload.dart';
import 'package:dony/features/tracking/data/tracking_queue_photo_store.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Étape reçue par le back. [photoDropped] : la photo a été refusée par le
/// serveur (limite, taille) et l'étape est partie sans elle.
final class SentScan {
  const SentScan(this.event, {this.photoDropped = false});
  final TrackingEventModel event;
  final bool photoDropped;
}

/// Étape partie sans sa photo parce que le fichier local avait disparu
/// (FLUTTER-MJ). Gardée jusqu'à ce que l'utilisateur ferme le message.
final class LostTrackingPhoto {
  const LostTrackingPhoto({required this.bidId, required this.eventType});
  final String bidId;
  final String eventType;

  Map<String, String> toJson() => {'bidId': bidId, 'eventType': eventType};

  static LostTrackingPhoto? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final bidId = raw['bidId'];
    final eventType = raw['eventType'];
    if (bidId is! String || eventType is! String) return null;
    return LostTrackingPhoto(bidId: bidId, eventType: eventType);
  }

  @override
  bool operator ==(Object other) =>
      other is LostTrackingPhoto &&
      other.bidId == bidId &&
      other.eventType == eventType;

  @override
  int get hashCode => Object.hash(bidId, eventType);
}

/// Photo d'une étape en file disparue du téléphone : remontée une seule
/// fois, en avertissement (l'étape part quand même, sans elle).
final class TrackingPhotoLostError implements SeverityAwareError {
  const TrackingPhotoLostError();

  @override
  ReportSeverity get reportSeverity => ReportSeverity.warning;

  @override
  String toString() => 'TrackingPhotoLostError';
}

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
  final ScanSendGuard _guard;

  /// Copies persistantes des photos de la file. `null` (tests) : la file
  /// garde le chemin d'origine de la photo, sans migration.
  final TrackingQueuePhotoStore? _photos;

  /// Clé des étapes parties sans leur photo disparue, dans `user_prefs`.
  static const lostPhotosKey = 'tracking_lost_photos';

  /// Clé des colis dont la remise resynchronisée a été refusée parce qu'ils
  /// ont été clos entre-temps, dans `user_prefs`. Propre au compte : vidée
  /// avec la box à la déconnexion (`AuthBloc._clearHiveAccountData`).
  static const closedScansKey = 'tracking_closed_before_sync';

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _syncing = false;

  /// Clés en cours d'envoi dans ce process. Perdues avec lui : au
  /// redémarrage, l'entrée encore en file est rejouée.
  final _inFlight = <Object?>{};

  /// Relance [syncAll] à la prochaine échéance d'une entrée pas encore due.
  Timer? _wakeUp;
  DateTime? _wakeUpAt;

  /// Premier délai avant un nouvel essai après un échec réseau, un délai
  /// dépassé ou un 5xx, doublé à chaque échec jusqu'à [retryMax]. Sans lui,
  /// une étape refusée restait en file jusqu'au prochain changement de
  /// réseau du téléphone, qui peut ne jamais venir : `connectivity_plus` ne
  /// signale rien tant que le téléphone reste sur le même réseau
  /// (FLUTTER-KZ, photo de suivi coupée en 4G ; FLUTTER-KK, 502 pendant un
  /// redéploiement du back).
  @visibleForTesting
  Duration retryBase = const Duration(seconds: 15);
  @visibleForTesting
  Duration retryMax = const Duration(minutes: 5);

  /// Délai du nouvel essai programmé, `null` quand rien n'est en échec.
  @visibleForTesting
  Duration? get nextRetryDelay => _retryDelay;

  Timer? _retry;
  Duration? _retryDelay;

  AppLifecycleListener? _lifecycle;

  /// Événements `handover_blocked_*` ([handoverBlockedEvent]). `null` en
  /// test.
  final AnalyticsService? _analytics;

  OfflineSyncService(
    this._hive,
    this._repository, [
    this._errorReporter,
    this._now = DateTime.now,
    ScanSendGuard? guard,
    this._photos,
    this._analytics,
  ]) : _guard = guard ?? ScanSendGuard.shared;

  void startListening() {
    // Le process a pu mourir avec des étapes en file (validation en attente
    // comprise) : elles repartent dès le démarrage, sans attendre un
    // changement de réseau.
    unawaited(syncAll());
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) syncAll();
    });
    // Retour au premier plan : le réseau a pu revenir sans que le téléphone
    // change de réseau, et les minuteries ne tournent pas en arrière-plan.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(syncAll()));
  }

  void dispose() {
    _sub?.cancel();
    _wakeUp?.cancel();
    _retry?.cancel();
    _lifecycle?.dispose();
  }

  /// Programme un nouvel essai de la file, chaque fois plus espacé : pour un
  /// envoi direct tombé sur un réseau affiché mais inutilisable, que
  /// `connectivity_plus` ne signalera pas (même réseau, FLUTTER-KZ).
  void scheduleRetry() => _scheduleRetry();

  /// Programme un nouvel essai, chaque fois plus espacé.
  void _scheduleRetry() {
    final previous = _retryDelay;
    final delay = previous == null
        ? retryBase
        : (previous * 2 > retryMax ? retryMax : previous * 2);
    _retryDelay = delay;
    _retry?.cancel();
    _retry = Timer(delay, () => unawaited(syncAll()));
  }

  /// Scans en attente de réseau. Une validation encore annulable ou en
  /// cours d'envoi n'en fait pas partie.
  int get pendingCount => _countWaiting((_) => true);

  /// Scans en attente qui concernent l'un de ces colis.
  int pendingCountFor(Set<String> bidIds) =>
      _countWaiting((raw) => bidIds.contains(raw['bidId']));

  /// Parmi eux, les remises qui attendent la décision de l'équipe sur une
  /// déclaration d'absence (dernier refus `handover-sender-noshow-pending`) :
  /// le retour du réseau ne suffira pas à les faire partir.
  int awaitingDecisionCountFor(Set<String> bidIds) => _countWaiting(
    (raw) =>
        bidIds.contains(raw['bidId']) &&
        raw[retryLaterCodeField] == senderNoShowPendingCode,
  );

  int _countWaiting(bool Function(Map raw) test) {
    final box = _hive.offlineQueue;
    final now = _now();
    var count = 0;
    for (final key in box.keys) {
      final raw = box.get(key);
      // Une étape refusée pour l'instant reste « en attente » pour
      // l'utilisateur malgré son échéance : la remise n'est pas validée.
      if (raw == null ||
          _inFlight.contains(key) ||
          (_notDue(raw, now) && raw[retryLaterField] != true)) {
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
  /// Suivi) ; sans, elle part au prochain [syncAll]. [photoKey] : photo déjà
  /// envoyée par un envoi direct qui a échoué ensuite, reprise sans être
  /// renvoyée (sa clé de stockage, comme [photoKeyField]).
  Future<int> queueScan({
    required String bidId,
    required String eventType,
    double? gpsLat,
    double? gpsLon,
    String? gpsLabel,
    String? photoPath,
    String? photoKey,
    ScanMethod? scanMethod,
    String? trackingNumber,
    DateTime? notBefore,
  }) async {
    // Copiée hors du cache temporaire, que le système purge (FLUTTER-MJ).
    // Jamais de chemin absolu en file avec le magasin de copies : sur iOS, il
    // change à chaque mise à jour de l'app (FLUTTER-F). Une copie ratée deux
    // fois : l'étape reste en file sans photo et l'utilisateur est prévenu.
    final photos = _photos;
    String? photoFile;
    var photoLost = false;
    if (photoPath != null && photos != null) {
      photoFile = await photos.keep(photoPath) ?? await photos.keep(photoPath);
      photoLost = photoFile == null;
    }
    final entry = <String, dynamic>{
      'bidId': bidId,
      'eventType': eventType,
      'gpsLat': ?gpsLat,
      'gpsLon': ?gpsLon,
      'gpsLabel': ?gpsLabel,
      if (photoFile != null)
        'photoFile': photoFile
      else if (photos == null)
        'photoPath': ?photoPath,
      photoKeyField: ?photoKey,
      // Absent des entrées mises en file avant la provenance : rien n'est
      // alors envoyé au back.
      'scanMethod': ?scanMethod?.wire,
      // Numéro saisi à la remise (DEPART) : il doit survivre à un envoi
      // différé, le serveur le vérifie à la réception.
      'trackingNumber': ?trackingNumber,
      'offlineTimestamp': _now().toUtc().toIso8601String(),
      'notBefore': ?notBefore?.toUtc().toIso8601String(),
    };
    final key = await _hive.offlineQueue.add(entry);
    if (photoLost) {
      await _reportLostPhoto(bidId: bidId, eventType: eventType);
    }
    return key;
  }

  /// Retire l'entrée [key] de la file : elle ne partira pas (« Annuler »).
  Future<void> discard(int key) => _delete(key, _hive.offlineQueue.get(key));

  /// Retire l'entrée de la file avec sa copie de photo.
  Future<void> _delete(Object? key, Map? entry) async {
    await _hive.offlineQueue.delete(key);
    await _photos?.remove(entry?['photoFile'] as String?);
  }

  /// Étapes de ces colis parties sans leur photo, disparue du téléphone.
  List<LostTrackingPhoto> lostPhotosFor(Set<String> bidIds) => [
    for (final lost in _lostPhotos())
      if (bidIds.contains(lost.bidId)) lost,
  ];

  /// Notifie chaque photo perdue ajoutée ou message fermé.
  Listenable get lostPhotoChanges =>
      _hive.userPrefs.listenable(keys: [lostPhotosKey]);

  /// L'utilisateur a lu le message : il disparaît.
  Future<void> dismissLostPhoto(LostTrackingPhoto lost) =>
      _hive.userPrefs.put(lostPhotosKey, [
        for (final other in _lostPhotos())
          if (other != lost) other.toJson(),
      ]);

  List<LostTrackingPhoto> _lostPhotos() {
    final raw = _hive.userPrefs.get(lostPhotosKey);
    if (raw is! List) return const [];
    return [for (final item in raw) ?LostTrackingPhoto.fromJson(item)];
  }

  /// Colis parmi [bidIds] dont la remise resynchronisée a été refusée : clos
  /// (absence confirmée, annulation) avant que le scan hors ligne parte.
  List<String> closedScansFor(Set<String> bidIds) => [
    for (final bidId in _closedScans())
      if (bidIds.contains(bidId)) bidId,
  ];

  /// Notifie chaque colis ajouté ou message fermé.
  Listenable get closedScanChanges =>
      _hive.userPrefs.listenable(keys: [closedScansKey]);

  /// Le voyageur a lu le message : il disparaît.
  Future<void> dismissClosedScan(String bidId) =>
      _hive.userPrefs.put(closedScansKey, [
        for (final other in _closedScans())
          if (other != bidId) other,
      ]);

  List<String> _closedScans() {
    final raw = _hive.userPrefs.get(closedScansKey);
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is String) item,
    ];
  }

  /// Remise (DEPART) hors ligne arrivée après la clôture du colis : le back
  /// la refuse (422 `bid-not-accepted`). Le voyageur en est prévenu dans
  /// l'onglet Suivi, une fois par colis.
  Future<void> _reportClosedScan(String bidId) async {
    final known = _closedScans();
    if (known.contains(bidId)) return;
    await _hive.userPrefs.put(closedScansKey, [...known, bidId]);
  }

  /// FLUTTER-MJ : le fichier de la photo n'existe plus. L'entrée oublie sa
  /// photo (un nouvel essai ne la cherchera plus et ne remontera rien), le
  /// cas est remonté une seule fois et l'utilisateur prévenu.
  Future<void> _forgetLostPhoto(Object? key, Map<String, dynamic> entry) async {
    final photoFile = entry.remove('photoFile') as String?;
    entry.remove('photoPath');
    if (_hive.offlineQueue.containsKey(key)) {
      await _hive.offlineQueue.put(key, entry);
    }
    await _photos?.remove(photoFile);
    await _reportLostPhoto(
      bidId: entry['bidId'] as String,
      eventType: entry['eventType'] as String,
    );
  }

  /// Prévient l'utilisateur (bannière, une fois par étape) et remonte le cas
  /// en avertissement.
  Future<void> _reportLostPhoto({
    required String bidId,
    required String eventType,
  }) async {
    final lost = LostTrackingPhoto(bidId: bidId, eventType: eventType);
    final known = _lostPhotos();
    if (!known.contains(lost)) {
      await _hive.userPrefs.put(lostPhotosKey, [
        for (final other in known) other.toJson(),
        lost.toJson(),
      ]);
    }
    unawaited(
      _errorReporter?.report(
        const TrackingPhotoLostError(),
        operation: 'tracking.photo_lost',
        context: {
          'feature': 'tracking',
          'channel': 'offline',
          'tracking_step': lost.eventType,
        },
      ),
    );
  }

  /// FLUTTER-F : entrée mise en file avant les copies (#599), avec le seul
  /// chemin absolu de la photo. Sa copie est reprise si le fichier se
  /// retrouve, et l'entrée réécrite avec son nom. Sinon elle garde son chemin
  /// et l'envoi suit le flux « photo perdue ».
  Future<void> _migrateLegacyPhoto(
    Object? key,
    Map<String, dynamic> entry,
  ) async {
    final photos = _photos;
    final legacyPath = entry['photoPath'];
    if (photos == null || legacyPath is! String || entry['photoFile'] != null) {
      return;
    }
    final name = await photos.adoptLegacy(legacyPath);
    if (name == null) return;
    entry
      ..['photoFile'] = name
      ..remove('photoPath');
    if (_hive.offlineQueue.containsKey(key)) {
      await _hive.offlineQueue.put(key, entry);
    }
  }

  Future<String?> _photoPathOf(Map<String, dynamic> entry) async {
    final photoFile = entry['photoFile'] as String?;
    final photos = _photos;
    if (photoFile != null && photos != null) return photos.resolve(photoFile);
    return entry['photoPath'] as String?;
  }

  /// Envoie tout de suite l'entrée [key], sans attendre son échéance, avec
  /// la [position] relevée entre-temps (écrite dans l'entrée avant l'envoi).
  ///
  /// Rend l'étape envoyée, ou `null` quand l'entrée reste en file (réseau,
  /// 5xx, session expirée : son échéance est alors levée et [syncAll] la
  /// reprend), n'existe plus ou part déjà par [syncAll]. Un refus définitif
  /// du back la retire de la file et remonte.
  Future<SentScan?> sendScheduled(
    int key, {
    Future<ScanPosition?>? position,
    bool canShowRefusal = true,
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
      return await _send(
        key,
        entry,
        deferred: false,
        canShowRefusal: canShowRefusal,
      );
    } catch (error, stackTrace) {
      final cause = unwrapDioError(error);
      // Refusée pour l'instant (supplément en attente) : affichable, elle est
      // déjà retirée et le motif remonte ; sinon _send l'a gardée en file
      // avec son échéance, comme une étape en attente de réseau.
      if (isRetryLaterTrackingRejection(cause)) {
        if (canShowRefusal) rethrow;
        return null;
      }
      // Refus définitif : déjà retirée par _send, l'appelant affiche le motif.
      if (isDefinitiveRejection(cause)) rethrow;
      _reportUnexpected(error, stackTrace, failedCount: 1);
      _scheduleRetry();
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
    _retry?.cancel();
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
          final cause = unwrapDioError(error);
          // Refusée pour l'instant : déjà repoussée par _send, elle repart à
          // son échéance sans compter comme une panne.
          if (isRetryLaterTrackingRejection(cause)) {
            final stored = _hive.offlineQueue.get(key);
            final due =
                (stored == null ? null : _notBefore(stored)) ??
                _now().add(retryLaterDelay);
            if (nextDue == null || due.isBefore(nextDue)) nextDue = due;
            continue;
          }
          // Refus définitif : déjà retirée par _send.
          if (isDefinitiveRejection(cause)) continue;
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
        _scheduleRetry();
      } else {
        _retryDelay = null;
      }
    } finally {
      _syncing = false;
      if (nextDue != null) {
        _wakeUp?.cancel();
        _wakeUpAt = nextDue;
        _wakeUp = Timer(nextDue.difference(_now()), () => unawaited(syncAll()));
      }
    }
  }

  /// Photo d'abord, puis l'étape ; l'entrée quitte la file au succès. Une
  /// photo refusée par le serveur ne fait pas échouer l'étape : elle part
  /// sans photo ([SentScan.photoDropped]). Seul un refus définitif de
  /// l'étape elle-même retire l'entrée en échec ; toute erreur remonte.
  /// [deferred] : envoi différé (hors ligne ou rejeu), daté de la mise en
  /// file.
  Future<SentScan> _send(
    Object? key,
    Map<String, dynamic> entry, {
    required bool deferred,
    bool canShowRefusal = false,
  }) async {
    final bidId = entry['bidId'] as String;
    final eventType = entry['eventType'] as String;
    var photoDropped = false;
    try {
      await _migrateLegacyPhoto(key, entry);
      final event = await _guard.postStepOnce(
        bidId: bidId,
        eventType: eventType,
        repository: _repository,
        post: () async {
          // Photo déjà envoyée par un essai précédent (étape refusée pour
          // l'instant, rejouée toutes les 5 min) : sa clé est reprise, sans
          // la renvoyer. Sinon 24 envois de la même photo en 2 h finissaient
          // sur la limite de photos du colis et le départ partait sans elle.
          final storedKey = entry[photoKeyField] as String?;
          String? photoKey = storedKey;
          if (storedKey == null) {
            // Une panne réseau pendant l'upload remonte telle quelle : elle
            // n'est pas un refus définitif, l'entrée reste en file.
            final photo = await uploadTrackingPhotoOrDrop(
              _repository,
              bidId: bidId,
              photoPath: await _photoPathOf(entry),
            );
            photoDropped = photo.dropped;
            photoKey = photo.key;
            if (photo.lost) await _forgetLostPhoto(key, entry);
            if (photoKey != null) await _rememberPhotoKey(key, entry, photoKey);
          }
          return _repository.postScan(
            bidId: bidId,
            eventType: eventType,
            gpsLat: (entry['gpsLat'] as num?)?.toDouble(),
            gpsLon: (entry['gpsLon'] as num?)?.toDouble(),
            gpsLabel: entry['gpsLabel'] as String?,
            photoUrl: photoKey,
            scanMethod: ScanMethod.fromWire(entry['scanMethod']),
            trackingNumber: entry['trackingNumber'] as String?,
            offlineTimestamp: deferred
                ? DateTime.parse(entry['offlineTimestamp'] as String)
                : null,
          );
        },
      );
      await _delete(key, entry);
      return SentScan(event, photoDropped: photoDropped);
    } catch (error) {
      final cause = unwrapDioError(error);
      if (isRetryLaterTrackingRejection(cause)) {
        // Remise refusée pour l'instant ([handoverRetryLaterCodes]) : un
        // supplément attend l'expéditeur, une modification le voyageur, ou
        // l'équipe tranche une absence contestée. Personne pour lire le motif
        // (scan hors ligne, onglet quitté, app fermée) : l'étape reste en
        // file, comptée parmi les scans en attente, et repart dans
        // [retryLaterDelay]. Envoi de l'onglet Suivi affiché
        // ([canShowRefusal]) : le voyageur voit le message et rescanne une
        // fois la réponse venue.
        // Événement au premier report seulement, pas à chaque rejeu.
        final firstBlock = entry[retryLaterField] != true;
        if (canShowRefusal) {
          await _delete(key, entry);
        } else {
          await _postpone(key, entry, code: cause.code);
        }
        final blocked = handoverBlockedEvent(cause.code);
        if (firstBlock && blocked != null) {
          unawaited(
            _analytics?.logEvent(
              blocked,
              properties: {'channel': deferred ? 'offline' : 'direct'},
            ),
          );
        }
        rethrow;
      }
      if (isDefinitiveRejection(cause)) {
        // Le serveur a tranché sur l'étape (409, 422, 404, 403) :
        // rejouer l'entrée à chaque retour du réseau ne changera rien et
        // gonflait Sentry côté back d'un 500 par tentative
        // (YADONY-BACK-STAGING-8, deux évènements à 8 s d'écart).
        await _delete(key, entry);
        // Remise hors ligne rejouée après la clôture du colis (absence
        // confirmée pendant l'attente) : personne ne lit le motif, le
        // voyageur en est prévenu dans l'onglet Suivi.
        if (deferred &&
            eventType == 'DEPART' &&
            cause is ValidationException &&
            cause.code == 'bid-not-accepted') {
          await _reportClosedScan(bidId);
        }
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
    // Photo présente mais illisible pour l'instant (téléphone verrouillé) :
    // passagère comme une panne réseau, l'étape repart au prochain essai.
    if (error is DioException || error is FileSystemException) return;
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

  /// Délai avant de renvoyer une étape refusée « pour l'instant »
  /// ([isRetryLaterTrackingRejection]).
  static const retryLaterDelay = Duration(minutes: 5);

  /// Refus d'une remise dont la déclaration d'absence est examinée par
  /// l'équipe : la décision peut prendre des jours.
  static const senderNoShowPendingCode = 'handover-sender-noshow-pending';

  /// Délais successifs des rejeux pour [senderNoShowPendingCode] : 5 min,
  /// 15 min, puis toutes les heures au plus.
  static const senderNoShowRetryDelays = [
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 60),
  ];

  /// Garde l'entrée en file avec une échéance : [retryLaterDelay], ou pour
  /// une absence examinée ([senderNoShowPendingCode]) un délai qui s'espace
  /// à chaque refus ([senderNoShowRetryDelays]). Le compteur vit dans
  /// l'entrée : il disparaît avec elle (étape partie ou abandonnée) et
  /// repart de zéro quand le motif du refus change.
  Future<void> _postpone(
    Object? key,
    Map<String, dynamic> entry, {
    required String? code,
  }) async {
    if (!_hive.offlineQueue.containsKey(key)) return;
    final sameCode = entry[retryLaterCodeField] == code;
    final count = (sameCode ? entry[retryLaterCountField] as int? ?? 0 : 0) + 1;
    final delay = code == senderNoShowPendingCode
        ? senderNoShowRetryDelays[count > senderNoShowRetryDelays.length
              ? senderNoShowRetryDelays.length - 1
              : count - 1]
        : retryLaterDelay;
    final due = _now().add(delay);
    entry
      ..['notBefore'] = due.toUtc().toIso8601String()
      ..[retryLaterField] = true
      ..[retryLaterCountField] = count
      ..[retryLaterCodeField] = code;
    await _hive.offlineQueue.put(key, entry);
    _wakeUpBy(due);
  }

  /// Champ de l'entrée : nombre de refus « pour l'instant » d'affilée pour
  /// le même motif.
  static const retryLaterCountField = 'retryLaterCount';

  /// Champ de l'entrée : code du dernier refus « pour l'instant ».
  static const retryLaterCodeField = 'retryLaterCode';

  /// Champ de l'entrée : clé de la photo déjà envoyée.
  static const photoKeyField = 'photoKey';

  /// Champ de l'entrée : étape refusée pour l'instant, en attente d'un
  /// nouvel essai. Elle reste comptée parmi les scans en attente malgré son
  /// échéance.
  static const retryLaterField = 'retryLater';

  /// Écrit la clé de la photo dans l'entrée, avant l'envoi de l'étape : un
  /// rejeu (ou un redémarrage) ne renvoie pas la photo.
  Future<void> _rememberPhotoKey(
    Object? key,
    Map<String, dynamic> entry,
    String photoKey,
  ) async {
    entry[photoKeyField] = photoKey;
    if (_hive.offlineQueue.containsKey(key)) {
      await _hive.offlineQueue.put(key, entry);
    }
  }

  /// Programme [syncAll] au plus tard à [due].
  void _wakeUpBy(DateTime due) {
    final current = _wakeUpAt;
    if (_wakeUp?.isActive == true && current != null && !current.isAfter(due)) {
      return;
    }
    _wakeUp?.cancel();
    _wakeUpAt = due;
    _wakeUp = Timer(due.difference(_now()), () => unawaited(syncAll()));
  }

  static DateTime? _notBefore(Map raw) {
    final value = raw['notBefore'] as String?;
    return value == null ? null : DateTime.parse(value);
  }

  static bool _notDue(Map raw, DateTime now) =>
      _notBefore(raw)?.isAfter(now) ?? false;

  /// Vrai quand le back a refusé le scan pour une raison qui ne dépend pas
  /// du réseau ni du moment : la même requête échouerait à l'identique.
  /// Délègue à [isDefinitiveTrackingRejection].
  static bool isDefinitiveRejection(AppException error) =>
      isDefinitiveTrackingRejection(error);
}
