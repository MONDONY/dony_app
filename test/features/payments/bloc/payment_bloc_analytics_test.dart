import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/payments/bloc/payment_bloc.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../../helpers/mock_analytics_backend.dart';

class _MockPaymentRepo extends Mock implements PaymentRepository {}

void main() {
  late _MockPaymentRepo repo;
  late MockAnalyticsBackend backend;

  setUp(() {
    repo = _MockPaymentRepo();
    backend = MockAnalyticsBackend();
  });

  PaymentBloc makeBloc({bool enabled = true}) {
    final a = enabled
        ? makeEnabledAnalytics(backend)
        : makeDisabledAnalytics(backend);
    a.onConfigured();
    return PaymentBloc(repo, a);
  }

  test(
    'payment_succeeded fires on PaymentSheetCompleted when state is PaymentSheetReady',
    () async {
      final bloc = makeBloc();
      bloc.emit(
        PaymentSheetReady(
          clientSecret: 'cs_test',
          amount: 45.0,
          commissionAmount: 5.0,
          paymentId: 'pay_1',
        ),
      );
      bloc.add(const PaymentSheetCompleted());
      await bloc.stream.firstWhere((s) => s is PaymentEscrowPending);
      await Future<void>.delayed(Duration.zero);
      verify(
        () => backend.capture(AnalyticsEvents.paymentSucceeded, {
          'method': 'card',
          'amount': 45.0,
          'payment_id': 'pay_1',
        }),
      ).called(1);
    },
  );

  test('payment_failed fires on PaymentFailed event', () async {
    final bloc = makeBloc();
    bloc.add(PaymentFailed('Card declined'));
    await bloc.stream.firstWhere((s) => s is PaymentError);
    await Future<void>.delayed(Duration.zero);
    verify(
      () => backend.capture(AnalyticsEvents.paymentFailed, any()),
    ).called(1);
  });

  test('no events when disabled', () async {
    final bloc = makeBloc(enabled: false);
    bloc.emit(
      PaymentSheetReady(
        clientSecret: 'cs_test',
        amount: 45.0,
        commissionAmount: 5.0,
        paymentId: 'pay_1',
      ),
    );
    bloc.add(const PaymentSheetCompleted());
    await bloc.stream.firstWhere((s) => s is PaymentEscrowPending);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => backend.capture(any(), any()));
  });
}
