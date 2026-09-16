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
    test(
      'requestRefund("EUR", []) poste sur /wallet/EUR/refund-request avec '
      'data: null',
      () async {
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
      },
    );

    test(
      'requestRefund("eur", ["t1"]) poste {transactionIds:[t1]} et '
      'majuscule la devise',
      () async {
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
      },
    );
  });
}
