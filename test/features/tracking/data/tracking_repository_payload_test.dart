import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/recording_dio.dart';

const _eventJson = {
  'id': 'ev-1',
  'bidId': 'bid-1',
  'eventType': 'DEPART',
  'scannedAt': '2026-06-01T10:00:00Z',
  'createdAt': '2026-06-01T10:00:01Z',
};

void main() {
  late RecordingApi api;
  late TrackingRepository repo;

  setUp(() {
    api = RecordingApi();
    repo = TrackingRepository(api.client);
  });

  test('postScan envoie tous les champs renseignés', () async {
    api.on('POST', '/tracking/events', _eventJson);

    final event = await repo.postScan(
      bidId: 'bid-1',
      eventType: 'DEPART',
      gpsLat: 48.8,
      gpsLon: 2.3,
      gpsLabel: 'Paris',
      photoUrl: 'tracking/bid-1/1_DEPART.jpg',
      offlineTimestamp: DateTime.utc(2026, 6, 1, 9, 59),
      scanMethod: ScanMethod.manual,
      trackingNumber: 'TRK123',
    );

    expect(event.id, 'ev-1');
    expect(api.last.data, {
      'bidId': 'bid-1',
      'eventType': 'DEPART',
      'gpsLat': 48.8,
      'gpsLon': 2.3,
      'gpsLabel': 'Paris',
      'photoUrl': 'tracking/bid-1/1_DEPART.jpg',
      'scanMethod': 'MANUAL',
      'trackingNumber': 'TRK123',
      'offlineTimestamp': '2026-06-01T09:59:00.000Z',
    });
  });

  test('uploadTrackingPhoto envoie le fichier et le bidId', () async {
    final dir = Directory.systemTemp.createTempSync('scan_photo');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/s.jpg')..writeAsBytesSync([1]);
    api.on('POST', '/storage/upload/tracking', {'key': 'tracking/bid-1/x.jpg'});

    final key = await repo.uploadTrackingPhoto('bid-1', file.path);

    expect(key, 'tracking/bid-1/x.jpg');
    final form = api.last.data as FormData;
    expect(form.fields.single.key, 'bidId');
    expect(form.fields.single.value, 'bid-1');
    expect(form.files.single.value.filename, 'scan.jpg');
  });

  group('refreshCode', () {
    test('lit le code, l’expiration et la visibilité', () async {
      api.on('POST', '/tracking/bid-1/refresh-code', {
        'confirmationCode': '123456',
        'expiresAt': '2026-06-01T12:00:00Z',
        'publicPageVisible': true,
      });
      final r = await repo.refreshCode('bid-1');
      expect(r.code, '123456');
      expect(r.expiresAt, DateTime.utc(2026, 6, 1, 12));
      expect(r.publicPageVisible, isTrue);
    });

    test('sans expiration ni visibilité', () async {
      api.on('POST', '/tracking/bid-1/refresh-code', {
        'confirmationCode': '654321',
      });
      final r = await repo.refreshCode('bid-1');
      expect(r.expiresAt, isNull);
      expect(r.publicPageVisible, isFalse);
    });
  });

  test('setConfirmationCodePublicVisible lit l’expiration', () async {
    api.on('POST', '/tracking/bid-1/confirmation-code/public', {
      'confirmationCode': '111111',
      'expiresAt': '2026-06-02T00:00:00Z',
      'publicPageVisible': false,
    });
    final r = await repo.setConfirmationCodePublicVisible(
      'bid-1',
      visible: false,
    );
    expect(api.last.queryParameters, {'visible': false});
    expect(r.expiresAt, DateTime.utc(2026, 6, 2));
    expect(r.publicPageVisible, isFalse);
  });
}
