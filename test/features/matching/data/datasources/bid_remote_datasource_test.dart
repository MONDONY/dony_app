import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/datasources/bid_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

final _bidJson = {
  'id': 'bid-001',
  'announcementId': 'ann-001',
  'senderId': 'sender-001',
  'weightKg': 5.0,
  'declaredValueEur': 100.0,
  'description': 'Vêtements',
  'status': 'PENDING',
  'voyageurConfirmed': false,
  'createdAt': '2024-05-01T00:00:00.000Z',
  'updatedAt': '2024-05-01T00:00:00.000Z',
};

Response<dynamic> _ok(dynamic data, String path) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late BidRemoteDatasource datasource;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    datasource = BidRemoteDatasource(mockClient);
  });

  // ── createBid ────────────────────────────────────────────────────────────────

  group('createBid', () {
    test('returns BidModel on success', () async {
      when(() => mockDio.post(
              '/announcements/ann-001/bids',
              data: any(named: 'data')))
          .thenAnswer((_) async => _ok(_bidJson, '/announcements/ann-001/bids'));

      final result = await datasource.createBid(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Vêtements',
        contentCategory: 'CLOTHING',
        recipientName: 'Fatou',
        recipientPhone: '+221',
      );

      expect(result.id, 'bid-001');
    });
  });

  // ── getBidsForAnnouncement ───────────────────────────────────────────────────

  group('getBidsForAnnouncement', () {
    test('returns list of bids', () async {
      when(() => mockDio.get('/announcements/ann-001/bids'))
          .thenAnswer((_) async =>
              _ok([_bidJson], '/announcements/ann-001/bids'));

      final results = await datasource.getBidsForAnnouncement('ann-001');

      expect(results, hasLength(1));
      expect(results.first.id, 'bid-001');
    });
  });

  // ── getBidById ───────────────────────────────────────────────────────────────

  group('getBidById', () {
    test('returns BidModel by id', () async {
      when(() => mockDio.get('/bids/bid-001'))
          .thenAnswer((_) async => _ok(_bidJson, '/bids/bid-001'));

      final result = await datasource.getBidById('bid-001');

      expect(result.id, 'bid-001');
    });
  });

  // ── getMyBids ────────────────────────────────────────────────────────────────

  group('getMyBids', () {
    test('returns list of own bids', () async {
      when(() => mockDio.get('/bids/me'))
          .thenAnswer((_) async => _ok([_bidJson, _bidJson], '/bids/me'));

      final results = await datasource.getMyBids();

      expect(results, hasLength(2));
    });
  });

  // ── acceptBid ────────────────────────────────────────────────────────────────

  group('acceptBid', () {
    test('returns accepted BidModel', () async {
      final accepted = {..._bidJson, 'status': 'ACCEPTED'};
      when(() => mockDio.put('/bids/bid-001/accept'))
          .thenAnswer((_) async => _ok(accepted, '/bids/bid-001/accept'));

      final result = await datasource.acceptBid('bid-001');

      expect(result.status, 'ACCEPTED');
    });
  });

  // ── rejectBid ────────────────────────────────────────────────────────────────

  group('rejectBid', () {
    test('returns rejected BidModel', () async {
      final rejected = {..._bidJson, 'status': 'REJECTED'};
      when(() => mockDio.put('/bids/bid-001/reject',
              data: any(named: 'data')))
          .thenAnswer((_) async => _ok(rejected, '/bids/bid-001/reject'));

      final result = await datasource.rejectBid('bid-001', reason: 'Trop lourd');

      expect(result.status, 'REJECTED');
    });

    test('rejectBid with null reason', () async {
      final rejected = {..._bidJson, 'status': 'REJECTED'};
      when(() => mockDio.put('/bids/bid-001/reject',
              data: any(named: 'data')))
          .thenAnswer((_) async => _ok(rejected, '/bids/bid-001/reject'));

      final result = await datasource.rejectBid('bid-001');
      expect(result.status, 'REJECTED');
    });
  });

  // ── cancelBid ────────────────────────────────────────────────────────────────

  group('cancelBid', () {
    test('returns cancelled BidModel (no reason)', () async {
      final cancelled = {..._bidJson, 'status': 'CANCELLED'};
      when(() => mockDio.put('/bids/bid-001/cancel',
              data: any(named: 'data')))
          .thenAnswer((_) async => _ok(cancelled, '/bids/bid-001/cancel'));

      final result = await datasource.cancelBid('bid-001');

      expect(result.status, 'CANCELLED');
    });

    test('cancelBid without reason sends null data body', () async {
      final cancelled = {..._bidJson, 'status': 'CANCELLED'};
      dynamic capturedData;
      when(() => mockDio.put('/bids/bid-001/cancel',
              data: any(named: 'data')))
          .thenAnswer((invocation) async {
        capturedData = invocation.namedArguments[const Symbol('data')];
        return _ok(cancelled, '/bids/bid-001/cancel');
      });

      await datasource.cancelBid('bid-001');

      expect(capturedData, isNull);
    });

    test('cancelBid with reason sends reason in PUT body', () async {
      final cancelled = {..._bidJson, 'status': 'CANCELLED'};
      dynamic capturedData;
      when(() => mockDio.put('/bids/bid-001/cancel',
              data: any(named: 'data')))
          .thenAnswer((invocation) async {
        capturedData = invocation.namedArguments[const Symbol('data')];
        return _ok(cancelled, '/bids/bid-001/cancel');
      });

      final result =
          await datasource.cancelBid('bid-001', reason: 'Colis trop lourd');

      expect(result.status, 'CANCELLED');
      expect(capturedData, isA<Map>());
      expect((capturedData as Map)['reason'], 'Colis trop lourd');
    });
  });

  // ── hideBid ──────────────────────────────────────────────────────────────────

  group('hideBid', () {
    test('calls DELETE and completes', () async {
      when(() => mockDio.delete('/bids/bid-001/me'))
          .thenAnswer((_) async => _ok(null, '/bids/bid-001/me'));

      await expectLater(datasource.hideBid('bid-001'), completes);
    });
  });

  // ── dismissBidAsTraveler ─────────────────────────────────────────────────────

  group('dismissBidAsTraveler', () {
    test('calls DELETE and completes', () async {
      when(() => mockDio.delete('/bids/bid-001/traveler'))
          .thenAnswer((_) async =>
              _ok(null, '/bids/bid-001/traveler'));

      await expectLater(datasource.dismissBidAsTraveler('bid-001'), completes);
    });
  });

  // ── setHandover ──────────────────────────────────────────────────────────────

  group('setHandover', () {
    test('returns BidModel with handover set', () async {
      final withHandover = {..._bidJson, 'handoverLocation': 'Gare du Nord'};
      when(() => mockDio.put('/bids/bid-001/handover',
              data: any(named: 'data')))
          .thenAnswer((_) async =>
              _ok(withHandover, '/bids/bid-001/handover'));

      final result = await datasource.setHandover(
        bidId: 'bid-001',
        location: 'Gare du Nord',
        windowStart: DateTime(2024, 6, 1, 10),
        windowEnd: DateTime(2024, 6, 1, 12),
      );

      expect(result.handoverLocation, 'Gare du Nord');
    });
  });

  // ── confirmPresence ──────────────────────────────────────────────────────────

  group('confirmPresence', () {
    test('returns BidModel after presence confirmed', () async {
      when(() => mockDio.put('/bids/bid-001/confirm-presence'))
          .thenAnswer((_) async =>
              _ok(_bidJson, '/bids/bid-001/confirm-presence'));

      final result = await datasource.confirmPresence('bid-001');

      expect(result.id, 'bid-001');
    });
  });
}
