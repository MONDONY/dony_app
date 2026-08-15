import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dony/core/services/error_reporting_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';

class OfflineSyncService {
  final HiveService _hive;
  final TrackingRepository _repository;
  final ErrorReportingService? _errorReporter;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _syncing = false;

  OfflineSyncService(this._hive, this._repository, [this._errorReporter]);

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
    String? gpsLabel,
    String? photoPath,
  }) async {
    final entry = <String, dynamic>{
      'bidId': bidId,
      'eventType': eventType,
      'gpsLat': ?gpsLat,
      'gpsLon': ?gpsLon,
      'gpsLabel': ?gpsLabel,
      'photoPath': ?photoPath,
      'offlineTimestamp': DateTime.now().toUtc().toIso8601String(),
    };
    await _hive.offlineQueue.add(entry);
  }

  Future<void> syncAll() async {
    if (_syncing || _hive.offlineQueue.isEmpty) return;
    _syncing = true;
    var failedCount = 0;
    Object? lastError;
    StackTrace? lastStackTrace;
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
            gpsLabel: entry['gpsLabel'] as String?,
            photoUrl: photoKey,
            offlineTimestamp: DateTime.parse(
              entry['offlineTimestamp'] as String,
            ),
          );
          await _hive.offlineQueue.delete(key);
        } catch (error, stackTrace) {
          // leave in queue for next retry
          failedCount++;
          lastError = error;
          lastStackTrace = stackTrace;
        }
      }
      if (failedCount > 0 && lastError is! DioException) {
        unawaited(
          _errorReporter?.report(
            lastError!,
            operation: 'tracking.offline_sync',
            stackTrace: lastStackTrace,
            context: {
              'feature': 'tracking',
              'channel': 'offline',
              'retry_count': failedCount,
            },
          ),
        );
      }
    } finally {
      _syncing = false;
    }
  }
}
