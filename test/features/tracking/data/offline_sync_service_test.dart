import 'dart:io';

import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockTrackingRepository extends Mock implements TrackingRepository {}

late Directory _tempDir;
late HiveService _hiveService;

Future<void> _setUp() async {
  _tempDir = await Directory.systemTemp.createTemp('offline_sync_test_');
  Hive.init(_tempDir.path);
  await Hive.openBox<Map>(HiveService.offlineQueueBox);
  await Hive.openBox(HiveService.userPrefsBox);
  _hiveService = HiveService();
}

Future<void> _tearDown() async {
  await Hive.close();
  await _tempDir.delete(recursive: true);
}

void main() {
  setUpAll(() async => _setUp());
  tearDownAll(() async => _tearDown());

  late MockTrackingRepository mockRepo;
  late OfflineSyncService service;

  setUp(() async {
    mockRepo = MockTrackingRepository();
    service = OfflineSyncService(_hiveService, mockRepo);
    await _hiveService.offlineQueue.clear();
  });

  group('pendingCount', () {
    test('returns 0 on empty queue', () {
      expect(service.pendingCount, 0);
    });

    test('returns count after queueScan', () async {
      await service.queueScan(bidId: 'bid-1', eventType: 'DEPART');
      expect(service.pendingCount, 1);
    });
  });

  group('queueScan', () {
    test('adds entry to queue with required fields', () async {
      await service.queueScan(bidId: 'bid-1', eventType: 'TRANSIT');
      final entry = Map<String, dynamic>.from(
          _hiveService.offlineQueue.values.first);
      expect(entry['bidId'], 'bid-1');
      expect(entry['eventType'], 'TRANSIT');
      expect(entry['offlineTimestamp'], isNotNull);
    });

    test('adds optional gps and photoPath when provided', () async {
      await service.queueScan(
        bidId: 'bid-2',
        eventType: 'ARRIVEE',
        gpsLat: 48.8566,
        gpsLon: 2.3522,
        photoPath: '/tmp/photo.jpg',
      );
      final entry = Map<String, dynamic>.from(
          _hiveService.offlineQueue.values.first);
      expect(entry['gpsLat'], 48.8566);
      expect(entry['gpsLon'], 2.3522);
      expect(entry['photoPath'], '/tmp/photo.jpg');
    });

    test('does not include null fields', () async {
      await service.queueScan(bidId: 'bid-3', eventType: 'DEPART');
      final entry = Map<String, dynamic>.from(
          _hiveService.offlineQueue.values.first);
      expect(entry.containsKey('gpsLat'), isFalse);
      expect(entry.containsKey('photoPath'), isFalse);
    });
  });

  group('syncAll', () {
    test('does nothing on empty queue', () async {
      await service.syncAll();
      verifyNever(() => mockRepo.postScan(
            bidId: any(named: 'bidId'),
            eventType: any(named: 'eventType'),
          ));
    });

    test('sends queued entries and removes them on success', () async {
      when(() => mockRepo.postScan(
            bidId: any(named: 'bidId'),
            eventType: any(named: 'eventType'),
            gpsLat: any(named: 'gpsLat'),
            gpsLon: any(named: 'gpsLon'),
            photoUrl: any(named: 'photoUrl'),
            offlineTimestamp: any(named: 'offlineTimestamp'),
          )).thenAnswer((_) async => _fakeEvent());
      when(() => mockRepo.uploadTrackingPhoto(any(), any()))
          .thenAnswer((_) async => 'photo-key');

      await service.queueScan(bidId: 'bid-1', eventType: 'TRANSIT');
      expect(service.pendingCount, 1);

      await service.syncAll();

      expect(service.pendingCount, 0);
      verify(() => mockRepo.postScan(
            bidId: 'bid-1',
            eventType: 'TRANSIT',
            gpsLat: any(named: 'gpsLat'),
            gpsLon: any(named: 'gpsLon'),
            photoUrl: any(named: 'photoUrl'),
            offlineTimestamp: any(named: 'offlineTimestamp'),
          )).called(1);
    });

    test('keeps entry in queue when postScan fails', () async {
      when(() => mockRepo.postScan(
            bidId: any(named: 'bidId'),
            eventType: any(named: 'eventType'),
            gpsLat: any(named: 'gpsLat'),
            gpsLon: any(named: 'gpsLon'),
            photoUrl: any(named: 'photoUrl'),
            offlineTimestamp: any(named: 'offlineTimestamp'),
          )).thenThrow(Exception('network error'));

      await service.queueScan(bidId: 'bid-2', eventType: 'DEPART');
      await service.syncAll();

      expect(service.pendingCount, 1);
    });

    test('syncs multiple entries successfully, empties the queue', () async {
      when(() => mockRepo.postScan(
            bidId: any(named: 'bidId'),
            eventType: any(named: 'eventType'),
            gpsLat: any(named: 'gpsLat'),
            gpsLon: any(named: 'gpsLon'),
            photoUrl: any(named: 'photoUrl'),
            offlineTimestamp: any(named: 'offlineTimestamp'),
          )).thenAnswer((_) async => _fakeEvent());
      when(() => mockRepo.uploadTrackingPhoto(any(), any()))
          .thenAnswer((_) async => 'photo-key');

      await service.queueScan(bidId: 'bid-1', eventType: 'TRANSIT');
      await service.queueScan(bidId: 'bid-2', eventType: 'ARRIVEE');
      await service.syncAll();

      expect(service.pendingCount, 0);
      verify(() => mockRepo.postScan(
            bidId: any(named: 'bidId'),
            eventType: any(named: 'eventType'),
            gpsLat: any(named: 'gpsLat'),
            gpsLon: any(named: 'gpsLon'),
            photoUrl: any(named: 'photoUrl'),
            offlineTimestamp: any(named: 'offlineTimestamp'),
          )).called(2);
    });
  });

  group('dispose', () {
    test('cancel does not throw when not started', () {
      final s = OfflineSyncService(_hiveService, mockRepo);
      expect(() => s.dispose(), returnsNormally);
    });
  });
}

TrackingEventModel _fakeEvent() => TrackingEventModel(
      id: 'ev-1',
      bidId: 'bid-1',
      eventType: 'TRANSIT',
      scannedAt: DateTime(2024, 6, 1),
      createdAt: DateTime(2024, 6, 1),
    );
