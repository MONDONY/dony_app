import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_requests_list_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_refund_request_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late MockWalletRepository repo;
  late WalletRefundRequestsListCubit cubit;

  setUp(() {
    repo = MockWalletRepository();
    cubit = WalletRefundRequestsListCubit(repo);
  });

  tearDown(() => cubit.close());

  final requests = [
    WalletRefundRequestModel(
      id: 'req-1',
      currency: 'EUR',
      amount: 40.00,
      channel: 'AUTOMATIC_STRIPE',
      status: 'PROCESSING',
      requestedAt: DateTime(2026, 8, 20),
    ),
  ];

  blocTest<WalletRefundRequestsListCubit, WalletRefundRequestsListState>(
    'load() succès',
    build: () {
      when(() => repo.getRefundRequests()).thenAnswer((_) async => requests);
      return cubit;
    },
    act: (c) => c.load(),
    expect: () => [
      isA<WalletRefundRequestsListState>().having(
        (s) => s.isLoading,
        'isLoading',
        isTrue,
      ),
      isA<WalletRefundRequestsListState>()
          .having((s) => s.isLoading, 'isLoading', isFalse)
          .having((s) => s.requests, 'requests', requests),
    ],
  );

  blocTest<WalletRefundRequestsListCubit, WalletRefundRequestsListState>(
    'load() échec',
    build: () {
      when(() => repo.getRefundRequests()).thenThrow(Exception('network'));
      return cubit;
    },
    act: (c) => c.load(),
    expect: () => [
      isA<WalletRefundRequestsListState>().having(
        (s) => s.isLoading,
        'isLoading',
        isTrue,
      ),
      isA<WalletRefundRequestsListState>()
          .having((s) => s.isLoading, 'isLoading', isFalse)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );
}
