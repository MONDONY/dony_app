import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/wallet/data/datasources/wallet_remote_datasource.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletRemoteDatasource extends Mock
    implements WalletRemoteDatasource {}

void main() {
  late MockWalletRemoteDatasource mockDatasource;
  late WalletRepository repo;

  setUp(() {
    mockDatasource = MockWalletRemoteDatasource();
    repo = WalletRepository(mockDatasource);
  });

  group('requestRefund', () {
    test('requestRefund(currency) délègue au datasource avec const [] et '
        'renvoie un WalletRefundRequestModel', () async {
      when(() => mockDatasource.requestRefund('EUR', const [])).thenAnswer(
        (_) async => {
          'id': 'r1',
          'currency': 'EUR',
          'amount': 35.0,
          'channel': 'AUTOMATIC_STRIPE',
          'status': 'PROCESSING',
          'requestedAt': '2026-09-15T00:00:00.000Z',
        },
      );

      final result = await repo.requestRefund('EUR');

      expect(result.id, 'r1');
      expect(result.currency, 'EUR');
      expect(result.amount, 35.0);
      verify(() => mockDatasource.requestRefund('EUR', const [])).called(1);
    });

    test('une DioException est convertie en AppException', () async {
      when(() => mockDatasource.requestRefund('EUR', const [])).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/wallet/EUR/refund-request'),
          error: const NetworkException('Erreur réseau'),
        ),
      );

      await expectLater(
        repo.requestRefund('EUR'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('getRefundEligibleTopups', () {
    test('mappe la liste en WalletEligibleTopupModel', () async {
      when(() => mockDatasource.getRefundEligibleTopups('EUR')).thenAnswer(
        (_) async => [
          {'id': 't1', 'amount': 20.0, 'createdAt': '2026-09-01T00:00:00.000Z'},
          {'id': 't2', 'amount': 15.0, 'createdAt': '2026-09-02T00:00:00.000Z'},
        ],
      );

      final result = await repo.getRefundEligibleTopups('EUR');

      expect(result, hasLength(2));
      expect(result[0].id, 't1');
      expect(result[1].amount, 15.0);
    });

    test('une DioException est convertie en AppException', () async {
      when(() => mockDatasource.getRefundEligibleTopups('EUR')).thenThrow(
        DioException(
          requestOptions: RequestOptions(
            path: '/wallet/EUR/refund-eligible-topups',
          ),
          error: const NetworkException('Erreur réseau'),
        ),
      );

      await expectLater(
        repo.getRefundEligibleTopups('EUR'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('getBalance', () {
    test('délègue au datasource et renvoie le WalletModel', () async {
      when(() => mockDatasource.getBalance()).thenAnswer(
        (_) async =>
            const WalletModel(balance: 47.5, currency: 'EUR', transactions: []),
      );

      final result = await repo.getBalance();

      expect(result.balance, 47.5);
      expect(result.currency, 'EUR');
      verify(() => mockDatasource.getBalance()).called(1);
    });

    test('une DioException est convertie en AppException', () async {
      when(() => mockDatasource.getBalance()).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/wallet/balance'),
          error: const NetworkException('Erreur réseau'),
        ),
      );

      await expectLater(repo.getBalance(), throwsA(isA<AppException>()));
    });
  });

  group('topupStripe', () {
    test(
      'force le moyen de paiement STRIPE et extrait le clientSecret',
      () async {
        when(
          () => mockDatasource.topup(
            amount: any(named: 'amount'),
            paymentMethod: any(named: 'paymentMethod'),
            currencyCode: any(named: 'currencyCode'),
          ),
        ).thenAnswer((_) async => {'clientSecret': 'pi_123_secret'});

        final result = await repo.topupStripe(amount: 20, currencyCode: 'CAD');

        expect(result, 'pi_123_secret');
        verify(
          () => mockDatasource.topup(
            amount: 20,
            paymentMethod: 'STRIPE',
            currencyCode: 'CAD',
          ),
        ).called(1);
      },
    );

    test('renvoie null quand le back omet clientSecret', () async {
      when(
        () => mockDatasource.topup(
          amount: any(named: 'amount'),
          paymentMethod: any(named: 'paymentMethod'),
          currencyCode: any(named: 'currencyCode'),
        ),
      ).thenAnswer((_) async => <String, dynamic>{});

      expect(await repo.topupStripe(amount: 20), isNull);
    });

    test('une DioException est convertie en AppException', () async {
      when(
        () => mockDatasource.topup(
          amount: any(named: 'amount'),
          paymentMethod: any(named: 'paymentMethod'),
          currencyCode: any(named: 'currencyCode'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/wallet/topup'),
          error: const NetworkException('Erreur réseau'),
        ),
      );

      await expectLater(
        repo.topupStripe(amount: 20),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('getRefundRequests', () {
    test('mappe la liste en WalletRefundRequestModel', () async {
      when(() => mockDatasource.getRefundRequests()).thenAnswer(
        (_) async => [
          {
            'id': 'r1',
            'currency': 'EUR',
            'amount': 35.0,
            'channel': 'AUTOMATIC_STRIPE',
            'status': 'PROCESSING',
            'requestedAt': '2026-09-15T00:00:00.000Z',
          },
          {
            'id': 'r2',
            'currency': 'XOF',
            'amount': 10000.0,
            'channel': 'MANUAL',
            'status': 'RESOLVED',
            'requestedAt': '2026-09-10T00:00:00.000Z',
            'resolvedAt': '2026-09-12T00:00:00.000Z',
          },
        ],
      );

      final result = await repo.getRefundRequests();

      expect(result, hasLength(2));
      expect(result[0].status, 'PROCESSING');
      expect(result[0].isTerminal, isFalse);
      expect(result[1].resolvedAt, DateTime.parse('2026-09-12T00:00:00.000Z'));
      expect(result[1].isSuccess, isTrue);
    });

    test('une DioException est convertie en AppException', () async {
      when(() => mockDatasource.getRefundRequests()).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/wallet/refund-requests'),
          error: const NetworkException('Erreur réseau'),
        ),
      );

      await expectLater(repo.getRefundRequests(), throwsA(isA<AppException>()));
    });
  });
}
