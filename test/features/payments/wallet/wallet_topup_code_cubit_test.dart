import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_topup_code_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_topup_code_redemption_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late MockWalletRepository repo;

  setUp(() => repo = MockWalletRepository());

  const redemption = WalletTopupCodeRedemptionModel(
    amount: 2000,
    currency: 'XOF',
    balance: 3500,
  );

  blocTest<WalletTopupCodeCubit, WalletTopupCodeState>(
    'submit() succès',
    build: () {
      when(
        () => repo.redeemTopupCode('DAKAR2000'),
      ).thenAnswer((_) async => redemption);
      return WalletTopupCodeCubit(repo);
    },
    act: (c) => c.submit('DAKAR2000'),
    expect: () => [
      isA<WalletTopupCodeSubmitting>(),
      isA<WalletTopupCodeSuccess>().having(
        (s) => s.redemption.currency,
        'currency',
        'XOF',
      ),
    ],
  );

  blocTest<WalletTopupCodeCubit, WalletTopupCodeState>(
    'submit() échec : AppException conservée (code métier)',
    build: () {
      when(() => repo.redeemTopupCode(any())).thenThrow(
        const ValidationException('Épuisé', code: 'topup-code-exhausted'),
      );
      return WalletTopupCodeCubit(repo);
    },
    act: (c) => c.submit('DAKAR2000'),
    expect: () => [
      isA<WalletTopupCodeSubmitting>(),
      isA<WalletTopupCodeFailure>().having(
        (s) => s.error.code,
        'code',
        'topup-code-exhausted',
      ),
    ],
  );

  blocTest<WalletTopupCodeCubit, WalletTopupCodeState>(
    'double tap : un seul appel pendant Submitting',
    build: () {
      when(() => repo.redeemTopupCode(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return redemption;
      });
      return WalletTopupCodeCubit(repo);
    },
    act: (c) {
      c.submit('DAKAR2000');
      c.submit('DAKAR2000');
    },
    wait: const Duration(milliseconds: 30),
    verify: (_) => verify(() => repo.redeemTopupCode(any())).called(1),
  );

  blocTest<WalletTopupCodeCubit, WalletTopupCodeState>(
    'code vide après trim : aucun appel',
    build: () => WalletTopupCodeCubit(repo),
    act: (c) => c.submit('   '),
    expect: () => <WalletTopupCodeState>[],
    verify: (_) => verifyNever(() => repo.redeemTopupCode(any())),
  );
}
