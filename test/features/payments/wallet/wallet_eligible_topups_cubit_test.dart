import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_eligible_topups_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_eligible_topup_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late MockWalletRepository repo;
  late WalletEligibleTopupsCubit cubit;

  setUp(() {
    repo = MockWalletRepository();
    cubit = WalletEligibleTopupsCubit(repo);
  });

  tearDown(() => cubit.close());

  final topups = [
    WalletEligibleTopupModel(
      id: 'tx-1',
      amount: 30.00,
      paymentRef: 'pi_111',
      createdAt: DateTime(2026, 8, 20),
    ),
  ];

  blocTest<WalletEligibleTopupsCubit, WalletEligibleTopupsState>(
    'load() succès',
    build: () {
      when(
        () => repo.getRefundEligibleTopups('EUR'),
      ).thenAnswer((_) async => topups);
      return cubit;
    },
    act: (c) => c.load('EUR'),
    expect: () => [
      isA<WalletEligibleTopupsState>().having(
        (s) => s.isLoading,
        'isLoading',
        isTrue,
      ),
      isA<WalletEligibleTopupsState>()
          .having((s) => s.isLoading, 'isLoading', isFalse)
          .having((s) => s.topups, 'topups', topups),
    ],
  );

  blocTest<WalletEligibleTopupsCubit, WalletEligibleTopupsState>(
    'load() échec',
    build: () {
      when(
        () => repo.getRefundEligibleTopups('EUR'),
      ).thenThrow(Exception('network'));
      return cubit;
    },
    act: (c) => c.load('EUR'),
    expect: () => [
      isA<WalletEligibleTopupsState>().having(
        (s) => s.isLoading,
        'isLoading',
        isTrue,
      ),
      isA<WalletEligibleTopupsState>()
          .having((s) => s.isLoading, 'isLoading', isFalse)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );
}
