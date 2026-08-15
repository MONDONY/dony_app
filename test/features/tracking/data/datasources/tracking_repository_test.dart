import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

Response<dynamic> _ok(dynamic data, String path) => Response(
  data: data,
  statusCode: 200,
  requestOptions: RequestOptions(path: path),
);

final _qrJson = {
  'bidId': 'bid-001',
  'scanUrl': 'https://api.dony.app/scan/abc',
  'qrCodeBase64': 'base64==',
};

final _searchJson = {
  'trackingNumber': 'DON-ABC123',
  'bidId': 'bid-001',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'currentStep': 'IN_TRANSIT',
  'stepLabel': 'En transit',
  'paymentStatus': 'ESCROW',
};

final _eventJson = {
  'id': 'ev-001',
  'bidId': 'bid-001',
  'eventType': 'TRANSIT',
  'scannedAt': '2024-06-01T10:00:00.000Z',
  'createdAt': '2024-06-01T10:00:00.000Z',
};

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late TrackingRepository repo;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    repo = TrackingRepository(mockClient);
  });

  // ── getQrCode ────────────────────────────────────────────────────────────────

  group('getQrCode', () {
    test('returns QrCodeModel on success', () async {
      when(
        () => mockDio.get('/tracking/bid-001/qr-code'),
      ).thenAnswer((_) async => _ok(_qrJson, '/tracking/bid-001/qr-code'));

      final result = await repo.getQrCode('bid-001');

      expect(result.bidId, 'bid-001');
      expect(result.qrCodeBase64, 'base64==');
    });
  });

  // ── searchByTrackingNumber ───────────────────────────────────────────────────

  group('searchByTrackingNumber', () {
    test('returns TrackingSearchModel', () async {
      when(
        () => mockDio.get(
          '/tracking/search',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((_) async => _ok(_searchJson, '/tracking/search'));

      final result = await repo.searchByTrackingNumber('DON-ABC123');

      expect(result.trackingNumber, 'DON-ABC123');
      expect(result.currentStep, 'IN_TRANSIT');
    });
  });

  // ── postScan ─────────────────────────────────────────────────────────────────

  group('postScan', () {
    test('returns TrackingEventModel on success', () async {
      when(
        () => mockDio.post('/tracking/events', data: any(named: 'data')),
      ).thenAnswer((_) async => _ok(_eventJson, '/tracking/events'));

      final result = await repo.postScan(
        bidId: 'bid-001',
        eventType: 'TRANSIT',
      );

      expect(result.id, 'ev-001');
      expect(result.eventType, 'TRANSIT');
    });

    test('includes optional gps and photo fields', () async {
      when(
        () => mockDio.post('/tracking/events', data: any(named: 'data')),
      ).thenAnswer((_) async => _ok(_eventJson, '/tracking/events'));

      final result = await repo.postScan(
        bidId: 'bid-001',
        eventType: 'DEPART',
        gpsLat: 48.8566,
        gpsLon: 2.3522,
        gpsLabel: 'Paris',
        photoUrl: 'tracking/bid-001/photo.jpg',
        offlineTimestamp: DateTime(2024, 6, 1, 8),
      );

      expect(result.bidId, 'bid-001');
      final payload =
          verify(
                () => mockDio.post(
                  '/tracking/events',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(payload['gpsLabel'], 'Paris');
    });
  });

  // ── getEvents ────────────────────────────────────────────────────────────────

  group('getEvents', () {
    test('returns list of TrackingEventModels', () async {
      when(
        () => mockDio.get('/tracking/bid-001/events'),
      ).thenAnswer((_) async => _ok([_eventJson], '/tracking/bid-001/events'));

      final results = await repo.getEvents('bid-001');

      expect(results, hasLength(1));
      expect(results.first.eventType, 'TRANSIT');
    });

    test('returns empty list when no events', () async {
      when(
        () => mockDio.get('/tracking/bid-001/events'),
      ).thenAnswer((_) async => _ok([], '/tracking/bid-001/events'));

      final results = await repo.getEvents('bid-001');
      expect(results, isEmpty);
    });
  });

  // ── getConfirmationCode ──────────────────────────────────────────────────────

  group('getConfirmationCode', () {
    test('returns code string', () async {
      when(() => mockDio.get('/tracking/bid-001/confirmation-code')).thenAnswer(
        (_) async => _ok({
          'confirmationCode': '4721',
          'publicPageVisible': true,
        }, '/tracking/bid-001/confirmation-code'),
      );

      final result = await repo.getConfirmationCode('bid-001');

      expect(result.code, '4721');
      expect(result.expiresAt, isNull);
      expect(result.publicPageVisible, isTrue);
    });

    test('returns null when confirmationCode absent', () async {
      when(() => mockDio.get('/tracking/bid-001/confirmation-code')).thenAnswer(
        (_) async => _ok({
          'confirmationCode': null,
          'publicPageVisible': false,
        }, '/tracking/bid-001/confirmation-code'),
      );

      final result = await repo.getConfirmationCode('bid-001');

      expect(result.code, isNull);
      expect(result.expiresAt, isNull);
      expect(result.publicPageVisible, isFalse);
    });
  });

  group('setConfirmationCodePublicVisible', () {
    test('posts visibility flag and returns updated public state', () async {
      when(
        () => mockDio.post(
          '/tracking/bid-001/confirmation-code/public',
          queryParameters: {'visible': true},
        ),
      ).thenAnswer(
        (_) async => _ok({
          'confirmationCode': '4721',
          'expiresAt': null,
          'publicPageVisible': true,
        }, '/tracking/bid-001/confirmation-code/public'),
      );

      final result = await repo.setConfirmationCodePublicVisible(
        'bid-001',
        visible: true,
      );

      expect(result.code, '4721');
      expect(result.publicPageVisible, isTrue);
    });
  });

  // ── confirmDelivery ──────────────────────────────────────────────────────────

  group('confirmDelivery', () {
    test('returns TrackingEventModel on success', () async {
      when(
        () => mockDio.post(
          '/tracking/bid-001/confirm-delivery',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok(_eventJson, '/tracking/bid-001/confirm-delivery'),
      );

      final result = await repo.confirmDelivery(bidId: 'bid-001', code: '4721');

      expect(result.id, 'ev-001');
    });
  });
}
