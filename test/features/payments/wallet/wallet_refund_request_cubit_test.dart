import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_request_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_refund_request_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late MockWalletRepository repo;
  late WalletRefundRequestCubit cubit;

  setUp(() {
    repo = MockWalletRepository();
    cubit = WalletRefundRequestCubit(repo);
  });

  tearDown(() => cubit.close());

  final result = WalletRefundRequestModel(
    id: 'req-1',
    currency: 'EUR',
    amount: 40.00,
    channel: 'AUTOMATIC_STRIPE',
    status: 'PROCESSING',
    requestedAt: DateTime(2026, 8, 20),
  );

  blocTest<WalletRefundRequestCubit, WalletRefundRequestState>(
    'submit() succès',
    build: () {
      when(() => repo.requestRefund('EUR')).thenAnswer((_) async => result);
      return cubit;
    },
    act: (c) => c.submit('EUR'),
    expect: () => [
      isA<WalletRefundRequestState>().having(
        (s) => s.isSubmitting,
        'isSubmitting',
        isTrue,
      ),
      isA<WalletRefundRequestState>()
          .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
          .having((s) => s.result?.id, 'result.id', 'req-1'),
    ],
  );

  blocTest<WalletRefundRequestCubit, WalletRefundRequestState>(
    'submit() échec',
    build: () {
      when(() => repo.requestRefund('EUR')).thenThrow(Exception('network'));
      return cubit;
    },
    act: (c) => c.submit('EUR'),
    expect: () => [
      isA<WalletRefundRequestState>().having(
        (s) => s.isSubmitting,
        'isSubmitting',
        isTrue,
      ),
      isA<WalletRefundRequestState>()
          .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );
}
