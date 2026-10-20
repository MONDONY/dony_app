import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';
import 'package:dony/features/payments/data/payer_account_source.dart';
import 'package:dony/features/payments/data/repositories/mobile_money_account_repository.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockAccountRepository extends Mock
    implements MobileMoneyAccountRepository {}

/// Catalogue du « compte qui paie » : celui de la recharge (DEPOSIT) ou celui
/// du versement (PAYOUT), derrière la même interface.
void main() {
  const countries = MobileMoneyCountries(upcoming: ['ML']);
  const catalog = MobileMoneyProviderCatalog(
    country: 'CI',
    currency: 'XOF',
    detected: 'ORANGE_CIV',
  );
  const e164 = '+2250748840856';

  group('TopupPayerAccountSource', () {
    late _MockWalletRepository wallet;
    late TopupPayerAccountSource source;

    setUp(() {
      wallet = _MockWalletRepository();
      source = TopupPayerAccountSource(wallet);
    });

    test('countries_readsDepositCatalogue', () async {
      when(() => wallet.mobileMoneyCountries()).thenAnswer((_) async => null);

      expect(await source.countries(), isNull);
      verify(() => wallet.mobileMoneyCountries()).called(1);
    });

    test('recognize_asksTopupProviders', () async {
      when(() => wallet.topupProviders(e164)).thenAnswer((_) async => catalog);

      expect(await source.recognize(e164), catalog);
    });
  });

  group('PayoutPayerAccountSource', () {
    late _MockAccountRepository accounts;
    late PayoutPayerAccountSource source;

    setUp(() {
      accounts = _MockAccountRepository();
      source = PayoutPayerAccountSource(accounts);
    });

    test('countries_readsPayoutCatalogue', () async {
      when(() => accounts.payoutCountries()).thenAnswer((_) async => countries);

      expect(await source.countries(), countries);
    });

    test('countries_oldBackend_null', () async {
      when(() => accounts.payoutCountries()).thenAnswer((_) async => null);

      expect(await source.countries(), isNull);
    });

    test('recognize_asksPayoutProviders', () async {
      when(
        () => accounts.payoutProviders(e164),
      ).thenAnswer((_) async => catalog);

      expect(await source.recognize(e164), catalog);
    });

    test('recognize_unwrapsDioError_soTheCodeIsReadable', () async {
      const invalid = ValidationException(
        'numéro invalide',
        code: 'mobile-money-invalid-phone',
      );
      when(() => accounts.payoutProviders(e164)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/payments/mobile-money'),
          error: invalid,
        ),
      );

      await expectLater(
        source.recognize(e164),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'mobile-money-invalid-phone',
          ),
        ),
      );
    });
  });
}
