import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/scan_send_guard.dart';
import 'package:dony/features/tracking/data/tracking_photo_upload.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';

/// Issue d'un envoi d'étape : parti vers le back, ou gardé dans la file hors
/// ligne pour être rejoué au retour du réseau.
sealed class ScanSubmitResult {
  const ScanSubmitResult();
}

final class ScanSubmitSent extends ScanSubmitResult {
  const ScanSubmitSent(this.event, {this.photoDropped = false});
  final TrackingEventModel event;

  /// La photo a été refusée par le serveur (limite, taille) : l'étape est
  /// enregistrée sans elle.
  final bool photoDropped;
}

final class ScanSubmitQueued extends ScanSubmitResult {
  const ScanSubmitQueued();
}

/// Envoi d'une étape DEPART/TRANSIT (`POST /tracking/events`), photo d'abord
/// si elle existe. Sans réseau, l'étape part dans la file hors ligne
/// ([OfflineSyncService]) au lieu d'échouer : téléphone sans aucun réseau,
/// mais aussi réseau affiché sur lequel rien ne passe (forfait épuisé,
/// signal trop faible, wifi d'aéroport), quand l'envoi échoue en route
/// ([isQueueableTrackingFailure]).
///
/// Utilisé par [TrackingBloc] (parcours photo puis confirmation). La
/// validation rapide de l'onglet Suivi passe, elle, par la file dès le
/// départ ([OfflineSyncService.sendScheduled]).
class ScanSubmitter {
  ScanSubmitter(
    this._repository,
    this._offlineSync, {
    Future<bool> Function()? isOnline,
    ScanSendGuard? guard,
  }) : _isOnline = isOnline ?? _connectivityOnline,
       _guard = guard ?? ScanSendGuard.shared;

  final TrackingRepository _repository;
  final OfflineSyncService _offlineSync;
  final Future<bool> Function() _isOnline;
  final ScanSendGuard _guard;

  static Future<bool> _connectivityOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<ScanSubmitResult> submit({
    required String bidId,
    required String eventType,
    String? photoPath,
    double? gpsLat,
    double? gpsLon,
    String? gpsLabel,
    ScanMethod? scanMethod,
    String? trackingNumber,
  }) async {
    // Photo de l'étape une fois réglée (envoyée, refusée ou perdue) ;
    // `null` tant qu'elle ne l'est pas.
    TrackingPhotoUpload? photo;

    Future<ScanSubmitResult> queue() async {
      await _offlineSync.queueScan(
        bidId: bidId,
        eventType: eventType,
        gpsLat: gpsLat,
        gpsLon: gpsLon,
        gpsLabel: gpsLabel,
        // Photo déjà envoyée : la file reprend sa clé sans la renvoyer.
        // Refusée : l'étape part sans elle. Perdue : son chemin repasse par
        // la file, qui prévient le voyageur (photo introuvable).
        photoPath: photo?.lost ?? true ? photoPath : null,
        photoKey: photo?.key,
        scanMethod: scanMethod,
        trackingNumber: trackingNumber,
      );
      return const ScanSubmitQueued();
    }

    if (!await _isOnline()) return queue();

    try {
      // Même verrou que la file : la même étape envoyée au même moment par
      // la file ou l'onglet Suivi ne part qu'une fois (FLUTTER-JV), et un
      // « déjà enregistré » du back est un succès.
      final event = await _guard.postStepOnce(
        bidId: bidId,
        eventType: eventType,
        repository: _repository,
        post: () async {
          final sent = photo = await uploadTrackingPhotoOrDrop(
            _repository,
            bidId: bidId,
            photoPath: photoPath,
          );
          return _repository.postScan(
            bidId: bidId,
            eventType: eventType,
            gpsLat: gpsLat,
            gpsLon: gpsLon,
            gpsLabel: gpsLabel,
            photoUrl: sent.key,
            scanMethod: scanMethod,
            trackingNumber: trackingNumber,
          );
        },
      );
      return ScanSubmitSent(
        event,
        photoDropped: photo?.dropped == true || photo?.lost == true,
      );
    } catch (error) {
      // Réseau affiché mais rien ne passe : l'étape est gardée au lieu
      // d'afficher une erreur et de faire tout recommencer au voyageur. Un
      // renvoi d'une étape que le back avait reçue (réponse perdue) revient
      // en « déjà enregistré », compté comme un succès ([ScanSendGuard]).
      if (!isQueueableTrackingFailure(error)) rethrow;
      final queued = await queue();
      // Le téléphone reste sur le même réseau : aucun changement ne
      // relancera la file, d'où un nouvel essai programmé.
      _offlineSync.scheduleRetry();
      return queued;
    }
  }
}
