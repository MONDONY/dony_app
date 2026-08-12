import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';

class OfflineSyncService {
  final HiveService _hive;
  final TrackingRepository _repository;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _syncing = false;

  OfflineSyncService(this._hive, this._repository);

  void startListening() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) syncAll();
    });
  }

  void dispose() => _sub?.cancel();

  int get pendingCount => _hive.offlineQueue.length;

  Future<void> queueScan({
    required String bidId,
    required String eventType,
    double? gpsLat,
    double? gpsLon,
    String? photoPath,
  }) async {
    final entry = <String, dynamic>{
      'bidId': bidId,
      'eventType': eventType,
      if (gpsLat != null) 'gpsLat': gpsLat,
      if (gpsLon != null) 'gpsLon': gpsLon,
      if (photoPath != null) 'photoPath': photoPath,
      'offlineTimestamp': DateTime.now().toUtc().toIso8601String(),
    };
    await _hive.offlineQueue.add(entry);
  }

  Future<void> syncAll() async {
    if (_syncing || _hive.offlineQueue.isEmpty) return;
    _syncing = true;
    try {
      final keys = _hive.offlineQueue.keys.toList();
      for (final key in keys) {
        final raw = _hive.offlineQueue.get(key);
        if (raw == null) continue;
        final entry = Map<String, dynamic>.from(raw);
        try {
          String? photoKey;
          final photoPath = entry['photoPath'] as String?;
          if (photoPath != null) {
            photoKey = await _repository.uploadTrackingPhoto(
              entry['bidId'] as String,
              photoPath,
            );
          }
          await _repository.postScan(
            bidId: entry['bidId'] as String,
            eventType: entry['eventType'] as String,
            gpsLat: (entry['gpsLat'] as num?)?.toDouble(),
            gpsLon: (entry['gpsLon'] as num?)?.toDouble(),
            photoUrl: photoKey,
            offlineTimestamp: DateTime.parse(
              entry['offlineTimestamp'] as String,
            ),
          );
          await _hive.offlineQueue.delete(key);
        } catch (_) {
          // leave in queue for next retry
        }
      }
    } finally {
      _syncing = false;
    }
  }
}
