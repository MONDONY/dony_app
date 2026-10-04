import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';

/// Issue d'un envoi d'étape : parti vers le back, ou gardé dans la file hors
/// ligne pour être rejoué au retour du réseau.
sealed class ScanSubmitResult {
  const ScanSubmitResult();
}

final class ScanSubmitSent extends ScanSubmitResult {
  const ScanSubmitSent(this.event);
  final TrackingEventModel event;
}

final class ScanSubmitQueued extends ScanSubmitResult {
  const ScanSubmitQueued();
}

/// Envoi d'une étape DEPART/TRANSIT (`POST /tracking/events`), photo d'abord
/// si elle existe. Sans réseau, l'étape part dans la file hors ligne
/// ([OfflineSyncService]) au lieu d'échouer.
///
/// Utilisé par [TrackingBloc] (parcours photo puis confirmation). La
/// validation rapide de l'onglet Suivi passe, elle, par la file dès le
/// départ ([OfflineSyncService.sendScheduled]).
class ScanSubmitter {
  ScanSubmitter(
    this._repository,
    this._offlineSync, {
    Future<bool> Function()? isOnline,
  }) : _isOnline = isOnline ?? _connectivityOnline;

  final TrackingRepository _repository;
  final OfflineSyncService _offlineSync;
  final Future<bool> Function() _isOnline;

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
    Future<ScanSubmitResult> queue() async {
      await _offlineSync.queueScan(
        bidId: bidId,
        eventType: eventType,
        gpsLat: gpsLat,
        gpsLon: gpsLon,
        gpsLabel: gpsLabel,
        photoPath: photoPath,
        scanMethod: scanMethod,
        trackingNumber: trackingNumber,
      );
      return const ScanSubmitQueued();
    }

    if (!await _isOnline()) return queue();

    String? photoKey;
    if (photoPath != null) {
      photoKey = await _repository.uploadTrackingPhoto(bidId, photoPath);
    }
    final event = await _repository.postScan(
      bidId: bidId,
      eventType: eventType,
      gpsLat: gpsLat,
      gpsLon: gpsLon,
      gpsLabel: gpsLabel,
      photoUrl: photoKey,
      scanMethod: scanMethod,
      trackingNumber: trackingNumber,
    );
    return ScanSubmitSent(event);
  }
}
