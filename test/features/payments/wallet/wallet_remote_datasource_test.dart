import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/payments/wallet/data/datasources/wallet_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockApiClient mockClient;
  late MockDio mockDio;
  late WalletRemoteDatasource datasource;

  setUp(() {
    mockClient = MockApiClient();
    mockDio = MockDio();
    when(() => mockClient.dio).thenReturn(mockDio);
    datasource = WalletRemoteDatasource(mockClient);
  });

  group('getBalance', () {
    test('parse un WalletModel depuis la réponse', () async {
      when(() => mockDio.get<dynamic>('/wallet/balance')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/wallet/balance'),
          statusCode: 200,
          data: {
            'balance': 47.5,
            'currency': 'EUR',
            'transactions': <dynamic>[],
          },
        ),
      );

      final result = await datasource.getBalance();

      expect(result.balance, 47.5);
      expect(result.currency, 'EUR');
      expect(result.transactions, isEmpty);
    });
  });

  group('getRefundEligibleTopups', () {
    test('appelle /wallet/{DEVISE}/refund-eligible-topups', () async {
      when(
        () => mockDio.get<dynamic>('/wallet/EUR/refund-eligible-topups'),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(
            path: '/wallet/EUR/refund-eligible-topups',
          ),
          statusCode: 200,
          data: <dynamic>[],
        ),
      );

      final result = await datasource.getRefundEligibleTopups('EUR');

      expect(result, isEmpty);
      verify(
        () => mockDio.get<dynamic>('/wallet/EUR/refund-eligible-topups'),
      ).called(1);
    });
  });

  group('requestRefund', () {
    test('requestRefund("EUR", []) poste sur /wallet/EUR/refund-request avec '
        'data: null', () async {
      when(
        () => mockDio.post<dynamic>(
          '/wallet/EUR/refund-request',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/wallet/EUR/refund-request'),
          statusCode: 200,
          data: {
            'id': 'r1',
            'currency': 'EUR',
            'amount': 35.0,
            'channel': 'AUTOMATIC_STRIPE',
            'status': 'PROCESSING',
            'requestedAt': '2026-09-15T00:00:00.000Z',
          },
        ),
      );

      await datasource.requestRefund('EUR', const []);

      // `data: null` explicite : le code réel passe toujours ce paramètre
      // nommé (même null), la vérification doit reproduire l'invocation
      // exacte plutôt que l'omettre.
      verify(
        () => mockDio.post<dynamic>(
          '/wallet/EUR/refund-request',
          // ignore: avoid_redundant_argument_values
          data: null,
        ),
      ).called(1);
    });

    test('requestRefund("eur", ["t1"]) poste {transactionIds:[t1]} et '
        'majuscule la devise', () async {
      when(
        () => mockDio.post<dynamic>(
          '/wallet/EUR/refund-request',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/wallet/EUR/refund-request'),
          statusCode: 200,
          data: {
            'id': 'r1',
            'currency': 'EUR',
            'amount': 35.0,
            'channel': 'AUTOMATIC_STRIPE',
            'status': 'PROCESSING',
            'requestedAt': '2026-09-15T00:00:00.000Z',
          },
        ),
      );

      await datasource.requestRefund('eur', const ['t1']);

      verify(
        () => mockDio.post<dynamic>(
          '/wallet/EUR/refund-request',
          data: {
            'transactionIds': ['t1'],
          },
        ),
      ).called(1);
    });
  });

  group('topup', () {
    Response<dynamic> okResponse() => Response(
      requestOptions: RequestOptions(path: '/wallet/topup'),
      statusCode: 200,
      data: {'clientSecret': 'pi_123_secret'},
    );

    test(
      'EUR : le corps omet currencyCode (devise par défaut du back)',
      () async {
        when(
          () =>
              mockDio.post<dynamic>('/wallet/topup', data: any(named: 'data')),
        ).thenAnswer((_) async => okResponse());

        final result = await datasource.topup(
          amount: 20,
          paymentMethod: 'STRIPE',
        );

        expect(result['clientSecret'], 'pi_123_secret');
        verify(
          () => mockDio.post<dynamic>(
            '/wallet/topup',
            data: {'amount': 20.0, 'paymentMethod': 'STRIPE'},
          ),
        ).called(1);
      },
    );

    test('devise non EUR : currencyCode ajouté et mis en majuscules', () async {
      when(
        () => mockDio.post<dynamic>('/wallet/topup', data: any(named: 'data')),
      ).thenAnswer((_) async => okResponse());

      await datasource.topup(
        amount: 10,
        paymentMethod: 'STRIPE',
        currencyCode: 'cad',
      );

      verify(
        () => mockDio.post<dynamic>(
          '/wallet/topup',
          data: {
            'amount': 10.0,
            'paymentMethod': 'STRIPE',
            'currencyCode': 'CAD',
          },
        ),
      ).called(1);
    });

    test('le montant est arrondi à 2 décimales avant l\'envoi', () async {
      when(
        () => mockDio.post<dynamic>('/wallet/topup', data: any(named: 'data')),
      ).thenAnswer((_) async => okResponse());

      // Sans le toStringAsFixed(2) du datasource, le back recevrait un
      // montant à plus de 2 décimales (les centimes n'existent pas côté
      // Stripe au-delà du centième).
      await datasource.topup(amount: 20.456, paymentMethod: 'STRIPE');

      final data =
          verify(
                () => mockDio.post<dynamic>(
                  '/wallet/topup',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(data['amount'], 20.46);
    });
  });

  group('getRefundRequests', () {
    test('renvoie la liste brute de /wallet/refund-requests', () async {
      when(() => mockDio.get<dynamic>('/wallet/refund-requests')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/wallet/refund-requests'),
          statusCode: 200,
          data: <dynamic>[
            {
              'id': 'r1',
              'currency': 'EUR',
              'amount': 35.0,
              'channel': 'AUTOMATIC_STRIPE',
              'status': 'PROCESSING',
              'requestedAt': '2026-09-15T00:00:00.000Z',
            },
          ],
        ),
      );

      final result = await datasource.getRefundRequests();

      expect(result, hasLength(1));
      verify(() => mockDio.get<dynamic>('/wallet/refund-requests')).called(1);
    });
  });

  test('le datasource ne convertit rien : la DioException remonte telle '
      'quelle (le repository seul la traduit)', () async {
    when(() => mockDio.get<dynamic>('/wallet/balance')).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/wallet/balance')),
    );

    await expectLater(datasource.getBalance(), throwsA(isA<DioException>()));
  });
}
