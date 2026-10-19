import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockPaymentGateway extends Mock implements PaymentGateway {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

/// YADONY-FLUTTER-PROD-10 : PayPal non activé sur Stripe live tombait en
/// échec générique. YADONY-FLUTTER-PROD-11 : Apple Pay sans certificat se
/// refermait en `Canceled`, sans aucune trace.
void main() {
  late _MockPaymentGateway gateway;
  late MockAnalyticsBackend backend;
  late List<({String message, bool suspicious, Map<String, Object> data})> logs;
  late DateTime clock;

  const config = PaymentSheetConfig(
    clientSecret: 'pi_123_secret_abc',
    amountEur: 56.0,
    paymentMethodTypes: ['card', 'paypal'],
    analyticsContext: 'bid',
  );

  setUp(() {
    gateway = _MockPaymentGateway();
    backend = MockAnalyticsBackend();
    logs = [];
    clock = DateTime(2026, 10, 19, 12);
    when(() => gateway.isPlatformPaySupported()).thenAnswer((_) async => true);
  });

  Future<PaymentSheetBloc> openSheet() async {
    final analytics = makeEnabledAnalytics(backend);
    await analytics.onConfigured();
    final bloc = PaymentSheetBloc(
      gateway: gateway,
      repository: _MockPaymentRepository(),
      config: config,
      analytics: analytics,
      now: () => clock,
      platformPayCancelLog: (message, {required suspicious, required data}) =>
          logs.add((message: message, suspicious: suspicious, data: data)),
    );
    addTearDown(bloc.close);
    bloc.add(const PaymentSheetStarted());
    await bloc.stream.firstWhere((s) => s is PaymentSheetResolved);
    return bloc;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void walletCancelsAfter(Duration elapsed) {
    when(
      () => gateway.confirmPlatformPay(
        clientSecret: any(named: 'clientSecret'),
        amountEur: any(named: 'amountEur'),
        currencyCode: any(named: 'currencyCode'),
      ),
    ).thenAnswer((_) async {
      clock = clock.add(elapsed);
      throw const PaymentCancelledException();
    });
  }

  test('PayPal non activé : échec methodUnavailable, reason tracée', () async {
    when(() => gateway.confirmPayPal(any())).thenThrow(
      const PaymentConfirmationException.fromStripe(
        null,
        stripeCode: 'Failed',
        stripeErrorCode: 'payment_intent_invalid_parameter',
        stripeErrorType: 'invalid_request_error',
        stripeMessage: 'The payment method type "paypal" is invalid.',
      ),
    );
    final bloc = await openSheet();

    bloc.add(const PaymentSheetPayPalPressed());
    final failure =
        await bloc.stream.firstWhere((s) => s is PaymentSheetFailure)
            as PaymentSheetFailure;
    await settle();

    expect(failure.reason, PaymentSheetFailureReason.methodUnavailable);
    final props =
        verify(
              () =>
                  backend.capture(AnalyticsEvents.paymentFailed, captureAny()),
            ).captured.single
            as Map<String, Object>;
    expect(props, containsPair('reason', 'method_unavailable'));
    expect(props, containsPair('method', 'paypal'));
  });

  test('Apple Pay refermé vite : log info, UX inchangée', () async {
    walletCancelsAfter(const Duration(seconds: 2));
    final bloc = await openSheet();

    bloc.add(const PaymentSheetWalletPressed());
    await bloc.stream.firstWhere((s) => s is PaymentSheetResolved);
    await settle();

    expect(logs, hasLength(1));
    expect(logs.single.message, PaymentSheetBloc.platformPayCancelledLog);
    expect(logs.single.suspicious, isFalse);
    expect(logs.single.data, containsPair('duration_ms', 2000));
    expect(logs.single.data, containsPair('context', 'bid'));
    verifyNever(() => backend.capture(AnalyticsEvents.paymentFailed, any()));
    verify(
      () => backend.capture(AnalyticsEvents.paymentCancelled, any()),
    ).called(1);
  });

  test('Apple Pay refermé après 8 s : log warn (échec probable)', () async {
    walletCancelsAfter(const Duration(seconds: 12));
    final bloc = await openSheet();

    bloc.add(const PaymentSheetWalletPressed());
    await bloc.stream.firstWhere((s) => s is PaymentSheetResolved);
    await settle();

    expect(logs.single.suspicious, isTrue);
    expect(logs.single.data, containsPair('duration_ms', 12000));
  });

  test('PayPal annulé : aucun log platform pay', () async {
    when(
      () => gateway.confirmPayPal(any()),
    ).thenThrow(const PaymentCancelledException());
    final bloc = await openSheet();

    bloc.add(const PaymentSheetPayPalPressed());
    await bloc.stream.firstWhere((s) => s is PaymentSheetResolved);
    await settle();

    expect(logs, isEmpty);
  });
}
