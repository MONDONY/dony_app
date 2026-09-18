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

  group('topupProviders', () {
    test(
      'délègue au datasource et mappe en MobileMoneyProviderCatalog',
      () async {
        when(() => mockDatasource.topupProviders('+2250700000000')).thenAnswer(
          (_) async => {
            'country': 'CI',
            'currency': 'XOF',
            'msisdnMasked': '+225 •• •• 56 78',
            'detected': 'ORANGE_CIV',
            'providers': [
              {'code': 'ORANGE_CIV', 'label': 'Orange Money', 'detected': true},
            ],
          },
        );

        final result = await repo.topupProviders('+2250700000000');

        expect(result.country, 'CI');
        expect(result.currency, 'XOF');
        expect(result.detected, 'ORANGE_CIV');
        expect(result.providers, hasLength(1));
        verify(() => mockDatasource.topupProviders('+2250700000000')).called(1);
      },
    );

    test('une DioException est convertie en AppException', () async {
      when(() => mockDatasource.topupProviders('+2250700000000')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/wallet/topup/providers'),
          error: const NetworkException('Erreur réseau'),
        ),
      );

      await expectLater(
        repo.topupProviders('+2250700000000'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('topupMobileMoney', () {
    test('délègue au datasource et mappe en WalletTopupModel', () async {
      when(
        () => mockDatasource.topupMobileMoney(
          amount: any(named: 'amount'),
          phoneNumber: any(named: 'phoneNumber'),
          provider: any(named: 'provider'),
        ),
      ).thenAnswer(
        (_) async => {
          'topupId': 't-1',
          'currency': 'XOF',
          'provider': 'ORANGE_CIV',
          'providerLabel': 'Orange Money',
          'msisdnMasked': '+225 •• •• 56 78',
        },
      );

      final result = await repo.topupMobileMoney(
        amount: 5000,
        phoneNumber: '+2250700000000',
        provider: 'ORANGE_CIV',
      );

      expect(result.topupId, 't-1');
      expect(result.provider, 'ORANGE_CIV');
      verify(
        () => mockDatasource.topupMobileMoney(
          amount: 5000,
          phoneNumber: '+2250700000000',
          provider: 'ORANGE_CIV',
        ),
      ).called(1);
    });

    test('une DioException est convertie en AppException', () async {
      when(
        () => mockDatasource.topupMobileMoney(
          amount: any(named: 'amount'),
          phoneNumber: any(named: 'phoneNumber'),
          provider: any(named: 'provider'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/wallet/topup'),
          error: const NetworkException('Erreur réseau'),
        ),
      );

      await expectLater(
        repo.topupMobileMoney(amount: 5000, phoneNumber: '+2250700000000'),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('topupStatus', () {
    test('délègue au datasource et mappe en WalletTopupStatusModel', () async {
      when(() => mockDatasource.topupStatus('t-1')).thenAnswer(
        (_) async => {
          'topupId': 't-1',
          'status': 'PENDING',
          'amount': 5000.0,
          'currency': 'XOF',
          'provider': 'ORANGE_CIV',
          'providerLabel': 'Orange Money',
          'msisdnMasked': '+225 •• •• 56 78',
        },
      );

      final result = await repo.topupStatus('t-1');

      expect(result.status, 'PENDING');
      expect(result.isTerminal, isFalse);
      verify(() => mockDatasource.topupStatus('t-1')).called(1);
    });

    test('une DioException est convertie en AppException', () async {
      when(() => mockDatasource.topupStatus('t-1')).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/wallet/topup/t-1/status'),
          error: const NetworkException('Erreur réseau'),
        ),
      );

      await expectLater(repo.topupStatus('t-1'), throwsA(isA<AppException>()));
    });
  });
}
