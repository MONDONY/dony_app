import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/datasources/bid_remote_datasource.dart';
import 'package:dony/features/matching/data/models/acceptance_response.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
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

  // ── checkoutBid ──────────────────────────────────────────────────────────────

  group('checkoutBid', () {
    final _checkoutJson = {
      'bidId': 'bid-001',
      'clientSecret': 'pi_secret_xxx',
      'publishableKey': 'pk_test_xxx',
      'expiresAt': '2030-01-01T00:00:00.000Z',
    };

    test('returns BidCheckoutResponseModel on success', () async {
      when(() => mockDio.post('/bids/checkout', data: any(named: 'data')))
          .thenAnswer((_) async => _ok(_checkoutJson, '/bids/checkout'));

      final result = await datasource.checkoutBid(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Vêtements',
        contentCategory: 'CLOTHING',
        recipientName: 'Fatou',
        recipientPhone: '+221',
      );

      expect(result.bidId, 'bid-001');
      expect(result.clientSecret, 'pi_secret_xxx');
    });

    test('checkoutBid with gridItems includes gridItems in body', () async {
      dynamic capturedBody;
      when(() => mockDio.post('/bids/checkout', data: any(named: 'data')))
          .thenAnswer((inv) async {
        capturedBody = inv.namedArguments[const Symbol('data')];
        return _ok(_checkoutJson, '/bids/checkout');
      });

      await datasource.checkoutBid(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Électronique',
        contentCategory: 'ELECTRONICS',
        recipientName: 'Mamadou',
        recipientPhone: '+221',
        gridItems: [
          {'announcementGridItemId': 'item-1', 'quantity': 2}
        ],
      );

      expect((capturedBody as Map)['gridItems'], isNotNull);
      expect((capturedBody)['gridItems'], hasLength(1));
    });

    test('checkoutBid without gridItems does not include gridItems in body',
        () async {
      dynamic capturedBody;
      when(() => mockDio.post('/bids/checkout', data: any(named: 'data')))
          .thenAnswer((inv) async {
        capturedBody = inv.namedArguments[const Symbol('data')];
        return _ok(_checkoutJson, '/bids/checkout');
      });

      await datasource.checkoutBid(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Vêtements',
        contentCategory: 'CLOTHING',
        recipientName: 'Fatou',
        recipientPhone: '+221',
      );

      expect((capturedBody as Map).containsKey('gridItems'), isFalse);
    });
  });

  // ── confirmPayment ────────────────────────────────────────────────────────────

  group('confirmPayment', () {
    test('calls POST and returns BidModel', () async {
      when(() => mockDio.post('/bids/bid-001/confirm-payment'))
          .thenAnswer((_) async => _ok(_bidJson, '/bids/bid-001/confirm-payment'));

      final result = await datasource.confirmPayment('bid-001');
      expect(result.id, 'bid-001');
    });
  });

  // ── acceptBidWithCommission ───────────────────────────────────────────────────

  group('acceptBidWithCommission', () {
    test('returns AcceptanceResponse on success', () async {
      final acceptedJson = {'status': 'ACCEPTED', 'clientSecret': null};
      when(() => mockDio.post('/bids/bid-001/accept-with-commission',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async =>
              _ok(acceptedJson, '/bids/bid-001/accept-with-commission'));

      final result = await datasource.acceptBidWithCommission('bid-001');
      expect(result.status, AcceptanceStatus.accepted);
    });

    test('sends WALLET_FIRST commissionSource by default', () async {
      dynamic capturedQuery;
      when(() => mockDio.post('/bids/bid-001/accept-with-commission',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((inv) async {
        capturedQuery = inv.namedArguments[const Symbol('queryParameters')];
        return _ok({'status': 'ACCEPTED'}, '/bids/bid-001/accept-with-commission');
      });

      await datasource.acceptBidWithCommission('bid-001');

      expect((capturedQuery as Map)['commissionSource'], 'WALLET_FIRST');
    });

    test('forwards CARD commissionSource when specified', () async {
      dynamic capturedQuery;
      when(() => mockDio.post('/bids/bid-001/accept-with-commission',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((inv) async {
        capturedQuery = inv.namedArguments[const Symbol('queryParameters')];
        return _ok({'status': 'ACCEPTED'}, '/bids/bid-001/accept-with-commission');
      });

      await datasource.acceptBidWithCommission('bid-001', commissionSource: 'CARD');

      expect((capturedQuery as Map)['commissionSource'], 'CARD');
    });

    test('returns requires3ds response when status is REQUIRES_3DS', () async {
      final json3ds = {
        'status': 'REQUIRES_3DS',
        'clientSecret': 'pi_xxx_secret',
      };
      when(() => mockDio.post('/bids/bid-001/accept-with-commission',
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async =>
              _ok(json3ds, '/bids/bid-001/accept-with-commission'));

      final result = await datasource.acceptBidWithCommission('bid-001');
      expect(result.status, AcceptanceStatus.requires3ds);
      expect(result.clientSecret, 'pi_xxx_secret');
    });

    test('parses 409 DioException body as insufficientWallet AcceptanceResponse',
        () async {
      final insufficientJson = {
        'status': 'INSUFFICIENT_WALLET',
        'availableBalance': 3.0,
        'requiredCommission': 12.0,
        'hasCard': true,
      };
      when(() => mockDio.post('/bids/bid-001/accept-with-commission',
              queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
        requestOptions:
            RequestOptions(path: '/bids/bid-001/accept-with-commission'),
        response: Response(
          requestOptions:
              RequestOptions(path: '/bids/bid-001/accept-with-commission'),
          statusCode: 409,
          data: insufficientJson,
        ),
      ));

      final result = await datasource.acceptBidWithCommission('bid-001');
      expect(result.status, AcceptanceStatus.insufficientWallet);
      expect(result.availableBalance, 3.0);
      expect(result.requiredCommission, 12.0);
      expect(result.hasCard, isTrue);
    });

    test('parses 422 DioException body as failed AcceptanceResponse', () async {
      final failedJson = {
        'status': 'FAILED',
        'error': 'Carte refusée',
      };
      when(() => mockDio.post('/bids/bid-001/accept-with-commission',
              queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
        requestOptions:
            RequestOptions(path: '/bids/bid-001/accept-with-commission'),
        response: Response(
          requestOptions:
              RequestOptions(path: '/bids/bid-001/accept-with-commission'),
          statusCode: 422,
          data: failedJson,
        ),
      ));

      final result = await datasource.acceptBidWithCommission('bid-001');
      expect(result.status, AcceptanceStatus.failed);
      expect(result.error, 'Carte refusée');
    });

    test('rethrows DioException non-409-422', () async {
      when(() => mockDio.post('/bids/bid-001/accept-with-commission',
              queryParameters: any(named: 'queryParameters')))
          .thenThrow(DioException(
        requestOptions:
            RequestOptions(path: '/bids/bid-001/accept-with-commission'),
        type: DioExceptionType.connectionTimeout,
      ));

      expect(
        () => datasource.acceptBidWithCommission('bid-001'),
        throwsA(isA<DioException>()),
      );
    });
  });

  // ── confirmCommissionAcceptance ───────────────────────────────────────────────

  group('confirmCommissionAcceptance', () {
    test('returns ConfirmResponse on success', () async {
      when(() => mockDio.post('/bids/bid-001/confirm-acceptance'))
          .thenAnswer((_) async => _ok(
              {'accepted': true}, '/bids/bid-001/confirm-acceptance'));

      final result = await datasource.confirmCommissionAcceptance('bid-001');
      expect(result.accepted, isTrue);
    });

    test('returns ConfirmResponse with error when not accepted', () async {
      when(() => mockDio.post('/bids/bid-001/confirm-acceptance'))
          .thenAnswer((_) async => _ok(
              {'accepted': false, 'error': 'Échec de confirmation'},
              '/bids/bid-001/confirm-acceptance'));

      final result = await datasource.confirmCommissionAcceptance('bid-001');
      expect(result.accepted, isFalse);
      expect(result.error, 'Échec de confirmation');
    });
  });

  // ── createBid with gridItems ─────────────────────────────────────────────────

  group('createBid with gridItems', () {
    test('includes gridItems in body when provided', () async {
      dynamic capturedBody;
      when(() => mockDio.post(
              '/announcements/ann-001/bids', data: any(named: 'data')))
          .thenAnswer((inv) async {
        capturedBody = inv.namedArguments[const Symbol('data')];
        return _ok(_bidJson, '/announcements/ann-001/bids');
      });

      await datasource.createBid(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Vêtements',
        contentCategory: 'CLOTHING',
        recipientName: 'Fatou',
        recipientPhone: '+221',
        gridItems: [
          {'announcementGridItemId': 'item-1', 'quantity': 1}
        ],
      );

      expect((capturedBody as Map)['gridItems'], isNotNull);
    });

    test('does not include gridItems when not provided', () async {
      dynamic capturedBody;
      when(() => mockDio.post(
              '/announcements/ann-001/bids', data: any(named: 'data')))
          .thenAnswer((inv) async {
        capturedBody = inv.namedArguments[const Symbol('data')];
        return _ok(_bidJson, '/announcements/ann-001/bids');
      });

      await datasource.createBid(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Vêtements',
        contentCategory: 'CLOTHING',
        recipientName: 'Fatou',
        recipientPhone: '+221',
      );

      expect((capturedBody as Map).containsKey('gridItems'), isFalse);
    });

    test('uses CASH payment method when specified', () async {
      dynamic capturedBody;
      when(() => mockDio.post(
              '/announcements/ann-001/bids', data: any(named: 'data')))
          .thenAnswer((inv) async {
        capturedBody = inv.namedArguments[const Symbol('data')];
        return _ok(_bidJson, '/announcements/ann-001/bids');
      });

      await datasource.createBid(
        announcementId: 'ann-001',
        weightKg: 5.0,
        declaredValueEur: 100.0,
        description: 'Vêtements',
        contentCategory: 'CLOTHING',
        recipientName: 'Fatou',
        recipientPhone: '+221',
        paymentMethod: BidPaymentMethod.cash,
      );

      expect((capturedBody as Map)['paymentMethod'], 'CASH');
    });
  });

  // ── quoteBid ─────────────────────────────────────────────────────────────────

  group('quoteBid', () {
    final _quoteJson = {
      'netEur': 65.0,
      'gridNetEur': 65.0,
      'kgNetEur': 0.0,
      'rate': 0.12,
      'commissionEur': 7.80,
      'totalEur': 72.80,
      'promoApplied': false,
      'promoLabel': null,
    };

    test('mode KG : inclut weightKg, omet gridItems', () async {
      dynamic capturedBody;
      when(() => mockDio.post('/bids/quote', data: any(named: 'data')))
          .thenAnswer((inv) async {
        capturedBody = inv.namedArguments[const Symbol('data')];
        return _ok(_quoteJson, '/bids/quote');
      });

      await datasource.quoteBid(announcementId: 'ann-001', weightKg: 5.0);

      final body = capturedBody as Map;
      expect(body['weightKg'], 5.0);
      expect(body.containsKey('gridItems'), isFalse);
    });

    test('mode GRID pur : omet weightKg (null/0), inclut gridItems', () async {
      dynamic capturedBody;
      when(() => mockDio.post('/bids/quote', data: any(named: 'data')))
          .thenAnswer((inv) async {
        capturedBody = inv.namedArguments[const Symbol('data')];
        return _ok(_quoteJson, '/bids/quote');
      });

      final result = await datasource.quoteBid(
        announcementId: 'ann-001',
        gridItems: [
          {'announcementGridItemId': 'item-1', 'quantity': 2}
        ],
      );

      final body = capturedBody as Map;
      expect(body.containsKey('weightKg'), isFalse);
      expect(body['gridItems'], hasLength(1));
      expect(result.gridNetEur, 65.0);
      expect(result.totalEur, 72.80);
    });

    test('weightKg = 0 est omis (le backend exige ≥ 0.1)', () async {
      dynamic capturedBody;
      when(() => mockDio.post('/bids/quote', data: any(named: 'data')))
          .thenAnswer((inv) async {
        capturedBody = inv.namedArguments[const Symbol('data')];
        return _ok(_quoteJson, '/bids/quote');
      });

      await datasource.quoteBid(
        announcementId: 'ann-001',
        weightKg: 0,
        gridItems: [
          {'announcementGridItemId': 'item-1', 'quantity': 1}
        ],
      );

      expect((capturedBody as Map).containsKey('weightKg'), isFalse);
    });

    test('promoCode envoyé en majuscules', () async {
      dynamic capturedBody;
      when(() => mockDio.post('/bids/quote', data: any(named: 'data')))
          .thenAnswer((inv) async {
        capturedBody = inv.namedArguments[const Symbol('data')];
        return _ok(_quoteJson, '/bids/quote');
      });

      await datasource.quoteBid(
        announcementId: 'ann-001',
        weightKg: 5.0,
        promoCode: 'welcome10',
      );

      expect((capturedBody as Map)['promoCode'], 'WELCOME10');
    });
  });
}
