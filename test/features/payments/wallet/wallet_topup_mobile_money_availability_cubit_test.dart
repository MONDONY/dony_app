import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_mobile_money_availability_cubit.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

/// Sonde de disponibilité du rail mobile money : la tuile de l'écran de
/// choix n'existe que si le backend déployé sert ce rail.
void main() {
  late _MockWalletRepository repo;

  setUp(() => repo = _MockWalletRepository());

  test('état initial : indisponible tant que la sonde n\'a pas répondu', () {
    final cubit = WalletTopupMobileMoneyAvailabilityCubit(repo);
    addTearDown(cubit.close);

    expect(cubit.state, isFalse);
  });

  blocTest<WalletTopupMobileMoneyAvailabilityCubit, bool>(
    'sonde réussie : disponible',
    build: () {
      when(
        () => repo.isMobileMoneyTopupAvailable(),
      ).thenAnswer((_) async => true);
      return WalletTopupMobileMoneyAvailabilityCubit(repo);
    },
    act: (c) => c.probe(),
    expect: () => [true],
  );

  blocTest<WalletTopupMobileMoneyAvailabilityCubit, bool>(
    'sonde en échec (prod gelée avant le lot 2) : reste indisponible, aucune '
    'erreur remontée',
    build: () {
      when(
        () => repo.isMobileMoneyTopupAvailable(),
      ).thenAnswer((_) async => false);
      return WalletTopupMobileMoneyAvailabilityCubit(repo);
    },
    act: (c) => c.probe(),
    expect: () => [false],
  );
}
