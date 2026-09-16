import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_refund_request_cubit.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_refund_request_model.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWalletRepository extends Mock implements WalletRepository {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late MockWalletRepository repo;
  late MockAnalyticsService analytics;
  late WalletRefundRequestCubit cubit;

  setUp(() {
    repo = MockWalletRepository();
    analytics = MockAnalyticsService();
    when(
      () => analytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    cubit = WalletRefundRequestCubit(repo, analytics);
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
      when(
        () => repo.requestRefund('EUR', ['tx-1']),
      ).thenAnswer((_) async => result);
      return cubit;
    },
    act: (c) => c.submit('EUR', ['tx-1']),
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
    verify: (_) {
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.walletRefundRequested,
          properties: {'source': 'wallet'},
        ),
      ).called(1);
    },
  );

  blocTest<WalletRefundRequestCubit, WalletRefundRequestState>(
    'submit sans sélection appelle le repository avec une liste vide',
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
          .having((s) => s.result, 'result', result),
    ],
    verify: (_) {
      verify(() => repo.requestRefund('EUR')).called(1);
    },
  );

  blocTest<WalletRefundRequestCubit, WalletRefundRequestState>(
    'submit() échec',
    build: () {
      when(
        () => repo.requestRefund('EUR', ['tx-1']),
      ).thenThrow(Exception('network'));
      return cubit;
    },
    act: (c) => c.submit('EUR', ['tx-1']),
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
    verify: (_) {
      verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      );
    },
  );
}
