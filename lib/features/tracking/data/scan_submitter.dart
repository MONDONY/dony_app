import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dony/core/error/app_exception.dart';
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
/// ([isQueueableScanFailure]).
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
    var photoSettled = false;
    Future<ScanSubmitResult> queue({String? photoKey}) async {
      await _offlineSync.queueScan(
        bidId: bidId,
        eventType: eventType,
        gpsLat: gpsLat,
        gpsLon: gpsLon,
        gpsLabel: gpsLabel,
        // Photo déjà réglée (envoyée, refusée ou perdue) : la file ne la
        // renvoie pas, elle reprend sa clé quand elle existe.
        photoPath: photoSettled ? null : photoPath,
        photoKey: photoKey,
        scanMethod: scanMethod,
        trackingNumber: trackingNumber,
      );
      return const ScanSubmitQueued();
    }

    if (!await _isOnline()) return queue();

    // Même verrou que la file : la même étape envoyée au même moment par la
    // file ou l'onglet Suivi ne part qu'une fois (FLUTTER-JV), et un « déjà
    // enregistré » du back est un succès.
    var photoDropped = false;
    String? photoKey;
    try {
      final event = await _guard.postStepOnce(
        bidId: bidId,
        eventType: eventType,
        repository: _repository,
        post: () async {
          final photo = await uploadTrackingPhotoOrDrop(
            _repository,
            bidId: bidId,
            photoPath: photoPath,
          );
          photoDropped = photo.dropped || photo.lost;
          photoKey = photo.key;
          photoSettled = true;
          return _repository.postScan(
            bidId: bidId,
            eventType: eventType,
            gpsLat: gpsLat,
            gpsLon: gpsLon,
            gpsLabel: gpsLabel,
            photoUrl: photoKey,
            scanMethod: scanMethod,
            trackingNumber: trackingNumber,
          );
        },
      );
      return ScanSubmitSent(event, photoDropped: photoDropped);
    } catch (error) {
      // Réseau affiché mais rien ne passe : l'étape est gardée au lieu
      // d'afficher une erreur et de faire tout recommencer au voyageur. Un
      // renvoi d'une étape que le back avait reçue (réponse perdue) revient
      // en « déjà enregistré », compté comme un succès ([ScanSendGuard]).
      if (!isQueueableScanFailure(unwrapDioError(error))) rethrow;
      return queue(photoKey: photoKey);
    }
  }
}

/// Vrai quand l'envoi d'une étape a échoué faute de réseau exploitable :
/// aucune connexion, délai dépassé, ou API injoignable (502, 503, 504,
/// connexion refusée). La même requête passera plus tard : l'étape va dans
/// la file. Un refus du serveur (409, 422, 403, 404) ou une erreur 500
/// reste affiché.
bool isQueueableScanFailure(AppException error) =>
    error is OfflineException ||
    error is TimeoutException ||
    error is ServiceUnavailableException;
