import 'package:dony/core/di/payer_account_injection.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/bloc/payer_account_cubit.dart';
import 'package:dony/features/payments/bloc/payer_account_state.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/data/payer_phone_memory.dart';
import 'package:dony/features/payments/data/repositories/mobile_money_account_repository.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/form_draft_test_doubles.dart';
import '../../helpers/mock_analytics_backend.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockAccountRepository extends Mock
    implements MobileMoneyAccountRepository {}

/// Le flux choisit le catalogue du compte qui paie : dépôts + mémoire pour la
/// recharge, versements sans mémoire pour l'ajout d'un compte de versement.
void main() {
  const orange = MobileMoneyOperator(
    code: 'ORANGE_CIV',
    label: 'Orange Money',
    brand: 'ORANGE',
  );
  const countries = MobileMoneyCountries(
    available: [
      MobileMoneyCountry(country: 'CI', currency: 'XOF', operators: [orange]),
    ],
  );

  late GetIt getIt;
  late _MockWalletRepository wallet;
  late _MockAccountRepository accounts;
  late InMemoryFormDraftStorage storage;

  setUp(() async {
    getIt = GetIt.asNewInstance();
    wallet = _MockWalletRepository();
    accounts = _MockAccountRepository();
    storage = InMemoryFormDraftStorage();
    when(
      () => wallet.mobileMoneyCountries(),
    ).thenAnswer((_) async => countries);
    when(() => accounts.payoutCountries()).thenAnswer((_) async => countries);
    final memory = PayerPhoneMemory(storage: storage, currentUid: () => 'u1');
    await memory.save(
      const RememberedPayer(
        country: 'CI',
        operatorCode: 'ORANGE_CIV',
        e164: '+2250748840856',
      ),
    );
    getIt
      ..registerSingleton<WalletRepository>(wallet)
      ..registerSingleton<MobileMoneyAccountRepository>(accounts)
      ..registerSingleton<PayerPhoneMemory>(memory)
      ..registerSingleton<AnalyticsService>(
        makeDisabledAnalytics(MockAnalyticsBackend()),
      );
    registerPayerAccountDependencies(getIt);
  });

  test(
    'topup : catalogue des dépôts, préremplissage depuis la mémoire',
    () async {
      when(
        () => wallet.topupProviders(any()),
      ).thenAnswer((_) async => throw StateError('hors sujet'));
      final cubit = getIt<PayerAccountCubit>(param1: 'topup');
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.flow, 'topup');
      expect(cubit.state.status, PayerAccountStatus.ready);
      expect(cubit.state.operator, orange);
      verify(() => wallet.mobileMoneyCountries()).called(1);
      verifyNever(() => accounts.payoutCountries());
    },
  );

  test('payout : catalogue des versements, aucun préremplissage', () async {
    final cubit = getIt<PayerAccountCubit>(param1: payerAccountPayoutFlow);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.flow, 'payout');
    expect(cubit.state.status, PayerAccountStatus.ready);
    expect(cubit.state.country, isNull);
    verify(() => accounts.payoutCountries()).called(1);
    verifyNever(() => wallet.mobileMoneyCountries());
  });

  test('une instance neuve par demande', () {
    final first = getIt<PayerAccountCubit>(param1: 'topup');
    final second = getIt<PayerAccountCubit>(param1: 'topup');
    addTearDown(first.close);
    addTearDown(second.close);

    expect(second, isNot(same(first)));
  });
}
