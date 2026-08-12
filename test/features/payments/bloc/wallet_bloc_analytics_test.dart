import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/payments/wallet/bloc/wallet_bloc.dart';
import 'package:dony/features/payments/wallet/data/repositories/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockWalletRepo extends Mock implements WalletRepository {}

void main() {
  late _MockWalletRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockWalletRepo();
    backend = MockAnalyticsBackend();
  });

  WalletBloc makeBloc({bool enabled = true}) {
    final a = enabled ? makeEnabledAnalytics(backend) : makeDisabledAnalytics(backend);
    a.onConfigured();
    return WalletBloc(repo, a);
  }

  test('wallet_topup_completed fires on WalletTopupStripeReady', () async {
    when(() => repo.topupStripe(amount: any(named: 'amount')))
        .thenAnswer((_) async => 'cs_test_secret');

    final bloc = makeBloc();
    bloc.add(WalletTopupRequested(amount: 50.0, paymentMethod: 'STRIPE'));
    await bloc.stream.firstWhere((s) => s is WalletTopupStripeReady);
    await Future<void>.delayed(Duration.zero);

    verify(() => backend.capture(
      AnalyticsEvents.walletTopupCompleted,
      {'amount': 50.0, 'method': 'STRIPE'},
    )).called(1);
  });

  test('no event when disabled', () async {
    when(() => repo.topupStripe(amount: any(named: 'amount')))
        .thenAnswer((_) async => 'cs_test_secret');
    final bloc = makeBloc(enabled: false);
    bloc.add(WalletTopupRequested(amount: 50.0, paymentMethod: 'STRIPE'));
    await bloc.stream.firstWhere((s) => s is WalletTopupStripeReady);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
