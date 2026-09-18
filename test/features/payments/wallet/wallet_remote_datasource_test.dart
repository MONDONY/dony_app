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

  group('topupProvidersProbe', () {
    test('poste sur /wallet/topup/providers SANS corps', () async {
      when(() => mockDio.post<dynamic>('/wallet/topup/providers')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/wallet/topup/providers'),
          statusCode: 200,
          data: <String, dynamic>{},
        ),
      );

      await datasource.topupProvidersProbe();

      verify(() => mockDio.post<dynamic>('/wallet/topup/providers')).called(1);
    });
  });

  group('topupProviders', () {
    test('poste le numéro sur /wallet/topup/providers', () async {
      when(
        () => mockDio.post<dynamic>(
          '/wallet/topup/providers',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/wallet/topup/providers'),
          statusCode: 200,
          data: {
            'country': 'CI',
            'currency': 'XOF',
            'msisdnMasked': '+225 •• •• 56 78',
            'detected': 'ORANGE_CIV',
            'providers': <dynamic>[],
          },
        ),
      );

      final result = await datasource.topupProviders('+2250700000000');

      expect(result['currency'], 'XOF');
      verify(
        () => mockDio.post<dynamic>(
          '/wallet/topup/providers',
          data: {'phoneNumber': '+2250700000000'},
        ),
      ).called(1);
    });
  });

  group('topupMobileMoney', () {
    Response<dynamic> okResponse() => Response(
      requestOptions: RequestOptions(path: '/wallet/topup'),
      statusCode: 200,
      data: {
        'topupId': 't-1',
        'currency': 'XOF',
        'provider': 'ORANGE_CIV',
        'providerLabel': 'Orange Money',
        'msisdnMasked': '+225 •• •• 56 78',
      },
    );

    test(
      'force paymentMethod MOBILE_MONEY et omet provider quand null',
      () async {
        when(
          () =>
              mockDio.post<dynamic>('/wallet/topup', data: any(named: 'data')),
        ).thenAnswer((_) async => okResponse());

        final result = await datasource.topupMobileMoney(
          amount: 5000,
          phoneNumber: '+2250700000000',
        );

        expect(result['topupId'], 't-1');
        verify(
          () => mockDio.post<dynamic>(
            '/wallet/topup',
            data: {
              'amount': 5000.0,
              'paymentMethod': 'MOBILE_MONEY',
              'phoneNumber': '+2250700000000',
            },
          ),
        ).called(1);
      },
    );

    test('provider transmis quand fourni', () async {
      when(
        () => mockDio.post<dynamic>('/wallet/topup', data: any(named: 'data')),
      ).thenAnswer((_) async => okResponse());

      await datasource.topupMobileMoney(
        amount: 5000,
        phoneNumber: '+2250700000000',
        provider: 'WAVE_CIV',
      );

      verify(
        () => mockDio.post<dynamic>(
          '/wallet/topup',
          data: {
            'amount': 5000.0,
            'paymentMethod': 'MOBILE_MONEY',
            'phoneNumber': '+2250700000000',
            'provider': 'WAVE_CIV',
          },
        ),
      ).called(1);
    });

    test('le montant est arrondi à 2 décimales avant l\'envoi', () async {
      when(
        () => mockDio.post<dynamic>('/wallet/topup', data: any(named: 'data')),
      ).thenAnswer((_) async => okResponse());

      await datasource.topupMobileMoney(
        amount: 5000.456,
        phoneNumber: '+2250700000000',
      );

      final data =
          verify(
                () => mockDio.post<dynamic>(
                  '/wallet/topup',
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(data['amount'], 5000.46);
    });
  });

  group('topupStatus', () {
    test('appelle GET /wallet/topup/{id}/status', () async {
      when(() => mockDio.get<dynamic>('/wallet/topup/t-1/status')).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/wallet/topup/t-1/status'),
          statusCode: 200,
          data: {
            'topupId': 't-1',
            'status': 'PENDING',
            'amount': 5000.0,
            'currency': 'XOF',
            'provider': 'ORANGE_CIV',
            'providerLabel': 'Orange Money',
            'msisdnMasked': '+225 •• •• 56 78',
          },
        ),
      );

      final result = await datasource.topupStatus('t-1');

      expect(result['status'], 'PENDING');
      verify(() => mockDio.get<dynamic>('/wallet/topup/t-1/status')).called(1);
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
