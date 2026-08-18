import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/datasources/bid_negotiation_remote_datasource.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

final _threadJson = {
  'bidId': 'bid-1',
  'announcementId': 'ann-1',
  'status': 'NEGOTIATING',
  'round': 1,
  'maxRounds': 6,
  'myTurn': false,
  'canCounter': true,
  'currency': 'EUR',
  'proposedGrossEur': 48.5,
};

final _checkoutJson = {
  'bidId': 'bid-1',
  'clientSecret': 'pi_123_secret_456',
  'publishableKey': 'pk_test_1',
  'expiresAt': '2026-08-19T04:12:00',
  'currency': 'eur',
  'paymentMethodTypes': ['card', 'paypal'],
};

final _summaryJson = {
  'bidId': 'bid-1',
  'announcementId': 'ann-1',
  'status': 'NEGOTIATING',
  'round': 1,
  'myTurn': true,
  'hasUnread': true,
  'proposedGrossEur': 48.5,
  'currency': 'EUR',
  'role': 'TRAVELER',
};

Response<dynamic> _ok(dynamic data, String path, {int status = 200}) =>
    Response(
      data: data,
      statusCode: status,
      requestOptions: RequestOptions(path: path),
    );

void main() {
  late MockApiClient client;
  late MockDio dio;
  late BidNegotiationRemoteDatasource datasource;

  setUp(() {
    client = MockApiClient();
    dio = MockDio();
    when(() => client.dio).thenReturn(dio);
    datasource = BidNegotiationRemoteDatasource(client);
  });

  Map<String, dynamic> capturedBody() =>
      verify(
            () => dio.post(any(), data: captureAny(named: 'data')),
          ).captured.single
          as Map<String, dynamic>;

  Future<BidNegotiation> propose({
    double? weightKg = 4.5,
    List<Map<String, dynamic>>? customItems,
    List<Map<String, dynamic>>? gridItems,
    List<String>? photoKeys,
    String? phoneNumber,
    String? countryCode,
  }) {
    when(
      () => dio.post(
        '/announcements/ann-1/bids/negotiation',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => _ok(
        _threadJson,
        '/announcements/ann-1/bids/negotiation',
        status: 201,
      ),
    );
    return datasource.propose(
      announcementId: 'ann-1',
      weightKg: weightKg,
      description: 'Deux pagnes',
      contentCategory: 'Vêtements',
      recipientName: 'Fatou',
      recipientPhone: '+221770000000',
      proposedTotalEur: 48.5,
      customItems: customItems,
      gridItems: gridItems,
      photoKeys: photoKeys,
      phoneNumber: phoneNumber,
      countryCode: countryCode,
    );
  }

  group('propose', () {
    test('appelle le bon chemin et renvoie le fil', () async {
      final thread = await propose();

      expect(thread.bidId, 'bid-1');
      expect(thread.proposedGrossEur, 48.5);
      verify(
        () => dio.post(
          '/announcements/ann-1/bids/negotiation',
          data: any(named: 'data'),
        ),
      ).called(1);
    });

    test('le corps porte le montant propose et le disclaimer', () async {
      await propose();
      final body = capturedBody();

      expect(body['proposedTotalEur'], 48.5);
      expect(body['description'], 'Deux pagnes');
      expect(body['contentCategory'], 'Vêtements');
      expect(body['recipientName'], 'Fatou');
      expect(body['recipientPhone'], '+221770000000');
      expect(body['disclaimerSigned'], isTrue);
      expect(body['paymentMethod'], 'STRIPE');
    });

    test('le poids est omis quand il est nul', () async {
      await propose(weightKg: null);
      expect(capturedBody().containsKey('weightKg'), isFalse);
    });

    test('le poids est omis quand il vaut zero', () async {
      await propose(weightKg: 0);
      expect(capturedBody().containsKey('weightKg'), isFalse);
    });

    test('le poids est envoye quand il est renseigne', () async {
      await propose(weightKg: 12.5);
      expect(capturedBody()['weightKg'], 12.5);
    });

    test('customItems et gridItems sont omis quand vides', () async {
      await propose(customItems: const [], gridItems: const []);
      final body = capturedBody();

      expect(body.containsKey('customItems'), isFalse);
      expect(body.containsKey('gridItems'), isFalse);
    });

    test('customItems et gridItems sont envoyes quand presents', () async {
      await propose(
        customItems: [
          {'label': 'Machine à coudre', 'quantity': 1, 'amountEur': 30.0},
        ],
        gridItems: [
          {'itemId': 'grid-1', 'quantity': 2},
        ],
      );
      final body = capturedBody();

      expect(body['customItems'], hasLength(1));
      expect(body['gridItems'], hasLength(1));
    });

    test('photoKeys, phoneNumber et countryCode sont optionnels', () async {
      await propose();
      final body = capturedBody();

      expect(body.containsKey('photoKeys'), isFalse);
      expect(body.containsKey('phoneNumber'), isFalse);
      expect(body.containsKey('countryCode'), isFalse);
    });

    test(
      'photoKeys, phoneNumber et countryCode passent quand fournis',
      () async {
        await propose(
          photoKeys: const ['k1'],
          phoneNumber: '+33600000000',
          countryCode: 'FR',
        );
        final body = capturedBody();

        expect(body['photoKeys'], ['k1']);
        expect(body['phoneNumber'], '+33600000000');
        expect(body['countryCode'], 'FR');
      },
    );

    test('un mode de paiement explicite est transmis', () async {
      when(
        () => dio.post(
          '/announcements/ann-1/bids/negotiation',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok(_threadJson, '/announcements/ann-1/bids/negotiation'),
      );
      await datasource.propose(
        announcementId: 'ann-1',
        weightKg: 1,
        description: 'd',
        contentCategory: 'c',
        recipientName: 'r',
        recipientPhone: 'p',
        proposedTotalEur: 10,
        paymentMethod: BidPaymentMethod.cash,
      );

      expect(capturedBody()['paymentMethod'], 'CASH');
    });

    test('laisse remonter la DioException brute', () async {
      when(
        () => dio.post(
          '/announcements/ann-1/bids/negotiation',
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(
            path: '/announcements/ann-1/bids/negotiation',
          ),
          response: _ok(
            {'detail': 'not negotiable'},
            '/announcements/ann-1/bids/negotiation',
            status: 422,
          ),
        ),
      );

      expect(
        () => datasource.propose(
          announcementId: 'ann-1',
          weightKg: 1,
          description: 'd',
          contentCategory: 'c',
          recipientName: 'r',
          recipientPhone: 'p',
          proposedTotalEur: 10,
        ),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('counter', () {
    test('poste le montant et le message', () async {
      when(
        () => dio.post(
          '/bids/bid-1/negotiation/counter',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok(_threadJson, '/bids/bid-1/negotiation/counter'),
      );

      final thread = await datasource.counter(
        'bid-1',
        proposedTotalEur: 52.0,
        body: 'Un peu plus lourd',
      );

      expect(thread.bidId, 'bid-1');
      final body = capturedBody();
      expect(body['proposedTotalEur'], 52.0);
      expect(body['body'], 'Un peu plus lourd');
    });

    test('le message est omis quand il est vide ou nul', () async {
      when(
        () => dio.post(
          '/bids/bid-1/negotiation/counter',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok(_threadJson, '/bids/bid-1/negotiation/counter'),
      );

      await datasource.counter('bid-1', proposedTotalEur: 52.0);
      expect(capturedBody().containsKey('body'), isFalse);

      await datasource.counter('bid-1', proposedTotalEur: 52.0, body: '  ');
      expect(capturedBody().containsKey('body'), isFalse);
    });
  });

  group('accept / reject / cancel', () {
    for (final entry in {
      'accept': '/bids/bid-1/negotiation/accept',
      'reject': '/bids/bid-1/negotiation/reject',
      'cancel': '/bids/bid-1/negotiation/cancel',
    }.entries) {
      test('${entry.key} poste sur ${entry.value}', () async {
        when(
          () => dio.post(entry.value),
        ).thenAnswer((_) async => _ok(_threadJson, entry.value));

        final thread = switch (entry.key) {
          'accept' => await datasource.accept('bid-1'),
          'reject' => await datasource.reject('bid-1'),
          _ => await datasource.cancel('bid-1'),
        };

        expect(thread.bidId, 'bid-1');
        verify(() => dio.post(entry.value)).called(1);
      });
    }
  });

  group('thread / markRead / myNegotiations', () {
    test('thread lit le fil', () async {
      when(
        () => dio.get('/bids/bid-1/negotiation'),
      ).thenAnswer((_) async => _ok(_threadJson, '/bids/bid-1/negotiation'));

      final thread = await datasource.thread('bid-1');
      expect(thread.status, 'NEGOTIATING');
    });

    test('markRead poste sans corps', () async {
      when(() => dio.post('/bids/bid-1/negotiation/read')).thenAnswer(
        (_) async => _ok(null, '/bids/bid-1/negotiation/read', status: 204),
      );

      await datasource.markRead('bid-1');
      verify(() => dio.post('/bids/bid-1/negotiation/read')).called(1);
    });

    test('myNegotiations mappe la liste', () async {
      when(
        () => dio.get('/bids/negotiations/me'),
      ).thenAnswer((_) async => _ok([_summaryJson], '/bids/negotiations/me'));

      final list = await datasource.myNegotiations();
      expect(list, hasLength(1));
      expect(list.single.bidId, 'bid-1');
      expect(list.single.role, 'TRAVELER');
    });

    test('myNegotiations renvoie une liste vide sur un corps vide', () async {
      when(
        () => dio.get('/bids/negotiations/me'),
      ).thenAnswer((_) async => _ok(<dynamic>[], '/bids/negotiations/me'));

      expect(await datasource.myNegotiations(), isEmpty);
    });
  });

  group('negotiationCheckout', () {
    test('poste sans corps et mappe la reponse de checkout', () async {
      when(() => dio.post('/bids/bid-1/negotiation/checkout')).thenAnswer(
        (_) async => _ok(_checkoutJson, '/bids/bid-1/negotiation/checkout'),
      );

      final checkout = await datasource.negotiationCheckout('bid-1');

      verify(() => dio.post('/bids/bid-1/negotiation/checkout')).called(1);
      expect(checkout.bidId, 'bid-1');
      expect(checkout.clientSecret, 'pi_123_secret_456');
      expect(checkout.publishableKey, 'pk_test_1');
      expect(checkout.currency, 'eur');
      expect(checkout.paymentMethodTypes, ['card', 'paypal']);
    });

    test('laisse remonter la DioException brute', () async {
      when(() => dio.post('/bids/bid-1/negotiation/checkout')).thenThrow(
        DioException(
          requestOptions: RequestOptions(
            path: '/bids/bid-1/negotiation/checkout',
          ),
        ),
      );

      expect(
        () => datasource.negotiationCheckout('bid-1'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('BidNegotiationRepository', () {
    late BidNegotiationRepository repository;

    setUp(() => repository = BidNegotiationRepository(datasource));

    test('propose delegue au datasource', () async {
      when(
        () => dio.post(
          '/announcements/ann-1/bids/negotiation',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _ok(_threadJson, '/announcements/ann-1/bids/negotiation'),
      );

      final thread = await repository.propose(
        announcementId: 'ann-1',
        weightKg: 4.5,
        description: 'd',
        contentCategory: 'c',
        recipientName: 'r',
        recipientPhone: 'p',
        proposedTotalEur: 48.5,
      );

      expect(thread.bidId, 'bid-1');
    });

    test('les erreurs traversent sans etre enveloppees', () async {
      when(() => dio.get('/bids/bid-1/negotiation')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/bids/bid-1/negotiation'),
        ),
      );

      expect(() => repository.thread('bid-1'), throwsA(isA<DioException>()));
    });

    test('les autres methodes deleguent', () async {
      for (final path in const [
        '/bids/bid-1/negotiation/counter',
        '/bids/bid-1/negotiation/accept',
        '/bids/bid-1/negotiation/reject',
        '/bids/bid-1/negotiation/cancel',
      ]) {
        when(
          () => dio.post(path, data: any(named: 'data')),
        ).thenAnswer((_) async => _ok(_threadJson, path));
        when(
          () => dio.post(path),
        ).thenAnswer((_) async => _ok(_threadJson, path));
      }
      when(
        () => dio.get('/bids/bid-1/negotiation'),
      ).thenAnswer((_) async => _ok(_threadJson, '/bids/bid-1/negotiation'));
      when(() => dio.post('/bids/bid-1/negotiation/read')).thenAnswer(
        (_) async => _ok(null, '/bids/bid-1/negotiation/read', status: 204),
      );
      when(
        () => dio.get('/bids/negotiations/me'),
      ).thenAnswer((_) async => _ok([_summaryJson], '/bids/negotiations/me'));

      expect(
        (await repository.counter('bid-1', proposedTotalEur: 1)).bidId,
        'bid-1',
      );
      expect((await repository.accept('bid-1')).bidId, 'bid-1');
      expect((await repository.reject('bid-1')).bidId, 'bid-1');
      expect((await repository.cancel('bid-1')).bidId, 'bid-1');
      expect((await repository.thread('bid-1')).bidId, 'bid-1');
      await repository.markRead('bid-1');
      expect(await repository.myNegotiations(), hasLength(1));
    });

    test('negotiationCheckout delegue au datasource', () async {
      when(() => dio.post('/bids/bid-1/negotiation/checkout')).thenAnswer(
        (_) async => _ok(_checkoutJson, '/bids/bid-1/negotiation/checkout'),
      );

      final checkout = await repository.negotiationCheckout('bid-1');

      expect(checkout.clientSecret, 'pi_123_secret_456');
      verify(() => dio.post('/bids/bid-1/negotiation/checkout')).called(1);
    });
  });
}
