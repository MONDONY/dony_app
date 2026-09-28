import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/scan_submitter.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements TrackingRepository {}

class _MockOfflineSync extends Mock implements OfflineSyncService {}

final _event = TrackingEventModel(
  id: 'e1',
  bidId: 'bid-1',
  eventType: 'TRANSIT',
  scannedAt: DateTime(2026, 9, 28),
  createdAt: DateTime(2026, 9, 28),
);

void main() {
  late _MockRepo repo;
  late _MockOfflineSync offline;
  late bool online;

  setUp(() {
    repo = _MockRepo();
    offline = _MockOfflineSync();
    online = true;
    when(
      () => offline.queueScan(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        photoPath: any(named: 'photoPath'),
      ),
    ).thenAnswer((_) async => 1);
    when(
      () => repo.uploadTrackingPhoto(any(), any()),
    ).thenAnswer((_) async => 'tracking/bid-1/photo.jpg');
    when(
      () => repo.postScan(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        photoUrl: any(named: 'photoUrl'),
      ),
    ).thenAnswer((_) async => _event);
  });

  ScanSubmitter build() =>
      ScanSubmitter(repo, offline, isOnline: () async => online);

  void verifyQueued() => verify(
    () => offline.queueScan(
      bidId: 'bid-1',
      eventType: 'TRANSIT',
      gpsLat: 14.7,
      photoPath: '/tmp/p.jpg',
    ),
  ).called(1);

  test('en ligne : photo envoyée puis étape', () async {
    final result = await build().submit(
      bidId: 'bid-1',
      eventType: 'TRANSIT',
      photoPath: '/tmp/p.jpg',
      gpsLat: 14.7,
    );
    expect((result as ScanSubmitSent).event, _event);
    verify(
      () => repo.postScan(
        bidId: 'bid-1',
        eventType: 'TRANSIT',
        gpsLat: 14.7,
        photoUrl: 'tracking/bid-1/photo.jpg',
      ),
    ).called(1);
  });

  test('provenance envoyée au back, en ligne comme en file', () async {
    when(
      () => repo.postScan(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        scanMethod: ScanMethod.manual,
      ),
    ).thenAnswer((_) async => _event);
    when(
      () => offline.queueScan(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        scanMethod: ScanMethod.manual,
      ),
    ).thenAnswer((_) async => 1);

    await build().submit(
      bidId: 'bid-1',
      eventType: 'TRANSIT',
      scanMethod: ScanMethod.manual,
    );
    online = false;
    await build().submit(
      bidId: 'bid-1',
      eventType: 'TRANSIT',
      scanMethod: ScanMethod.manual,
    );

    verify(
      () => repo.postScan(
        bidId: 'bid-1',
        eventType: 'TRANSIT',
        scanMethod: ScanMethod.manual,
      ),
    ).called(1);
    verify(
      () => offline.queueScan(
        bidId: 'bid-1',
        eventType: 'TRANSIT',
        scanMethod: ScanMethod.manual,
      ),
    ).called(1);
  });

  test('en ligne sans photo : pas d\'upload', () async {
    await build().submit(bidId: 'bid-1', eventType: 'TRANSIT');
    verifyNever(() => repo.uploadTrackingPhoto(any(), any()));
  });

  test('hors ligne : file d\'attente, aucun appel', () async {
    online = false;
    final result = await build().submit(
      bidId: 'bid-1',
      eventType: 'TRANSIT',
      photoPath: '/tmp/p.jpg',
      gpsLat: 14.7,
    );
    expect(result, isA<ScanSubmitQueued>());
    verifyQueued();
    verifyNever(() => repo.uploadTrackingPhoto(any(), any()));
  });

  test('réseau coupé pendant l\'envoi : l\'erreur remonte', () async {
    when(
      () => repo.uploadTrackingPhoto(any(), any()),
    ).thenThrow(const TimeoutException());
    await expectLater(
      build().submit(
        bidId: 'bid-1',
        eventType: 'TRANSIT',
        photoPath: '/tmp/p.jpg',
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('refus du back : jamais mis en file', () async {
    when(
      () => repo.postScan(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        photoUrl: any(named: 'photoUrl'),
      ),
    ).thenThrow(const ConflictException('déjà scanné'));
    await expectLater(
      build().submit(bidId: 'bid-1', eventType: 'DEPART'),
      throwsA(isA<ConflictException>()),
    );
    verifyNever(
      () => offline.queueScan(
        bidId: any(named: 'bidId'),
        eventType: any(named: 'eventType'),
        gpsLat: any(named: 'gpsLat'),
        gpsLon: any(named: 'gpsLon'),
        gpsLabel: any(named: 'gpsLabel'),
        photoPath: any(named: 'photoPath'),
      ),
    );
  });
}
