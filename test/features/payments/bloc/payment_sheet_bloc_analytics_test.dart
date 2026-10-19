import 'package:dony/core/config/payment_methods_flag.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/payments/bloc/payment_sheet_bloc.dart';
import 'package:dony/features/payments/data/models/ephemeral_key_model.dart';
import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:dony/features/payments/data/repositories/payment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class _MockPaymentGateway extends Mock implements PaymentGateway {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

/// La feuille de paiement est le seul point de passage des paiements Stripe :
/// c'est elle qui émet le tunnel `payment_sheet_opened` → `payment_initiated`
/// → `payment_succeeded` / `payment_cancelled` / `payment_failed`, avec le
/// moyen réellement utilisé (il partait en `card` codé en dur).
void main() {
  late _MockPaymentGateway gateway;
  late _MockPaymentRepository repository;
  late MockAnalyticsBackend backend;

  const config = PaymentSheetConfig(
    clientSecret: 'pi_123_secret_abc',
    amountEur: 56.0,
    currencyCode: 'XOF',
    paymentMethodTypes: ['card', 'paypal'],
    analyticsContext: 'bid',
  );

  tearDown(resetPaymentMethodFlagsForTest);

  setUp(() async {
    resetPaymentMethodFlagsForTest();
    gateway = _MockPaymentGateway();
    repository = _MockPaymentRepository();
    backend = MockAnalyticsBackend();
    when(() => gateway.isPlatformPaySupported()).thenAnswer((_) async => true);
  });

  Future<PaymentSheetBloc> buildBloc({
    bool enabled = true,
    PaymentMethodFlags flags = const PaymentMethodFlags(
      applePay: true,
      googlePay: true,
    ),
  }) async {
    final analytics = enabled
        ? makeEnabledAnalytics(backend)
        : makeDisabledAnalytics(backend);
    await analytics.onConfigured();
    return PaymentSheetBloc(
      gateway: gateway,
      repository: repository,
      config: config,
      analytics: analytics,
      loadPaymentMethodFlags: () async => flags,
    );
  }

  /// Ouvre la feuille et attend que les moyens soient résolus.
  Future<PaymentSheetBloc> openSheet({
    bool enabled = true,
    PaymentMethodFlags flags = const PaymentMethodFlags(
      applePay: true,
      googlePay: true,
    ),
  }) async {
    final bloc = await buildBloc(enabled: enabled, flags: flags);
    bloc.add(const PaymentSheetStarted());
    await bloc.stream.firstWhere((s) => s is PaymentSheetResolved);
    return bloc;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Map<String, Object> capturedFor(String event) =>
      verify(() => backend.capture(event, captureAny())).captured.single
          as Map<String, Object>;

  test('payment_sheet_opened : contexte, devise, tranche, moyens', () async {
    await openSheet();
    await settle();

    expect(capturedFor(AnalyticsEvents.paymentSheetOpened), {
      'context': 'bid',
      'currency': 'XOF',
      'amount_bracket': '50-100',
      'wallet_available': true,
      'paypal_available': true,
    });
  });

  test(
    'payment_sheet_opened : wallet_available suit le drapeau serveur',
    () async {
      await openSheet(flags: PaymentMethodFlags.none);
      await settle();

      expect(
        capturedFor(AnalyticsEvents.paymentSheetOpened)['wallet_available'],
        false,
        reason: 'appareil compatible mais Google Pay éteint côté serveur',
      );
    },
  );

  test('wallet réussi : initiated puis succeeded en `platform_pay`', () async {
    when(
      () => gateway.confirmPlatformPay(
        clientSecret: any(named: 'clientSecret'),
        amountEur: any(named: 'amountEur'),
        currencyCode: any(named: 'currencyCode'),
      ),
    ).thenAnswer((_) async {});
    final bloc = await openSheet();

    bloc.add(const PaymentSheetWalletPressed());
    await bloc.stream.firstWhere((s) => s is PaymentSheetSuccess);
    await settle();

    expect(
      capturedFor(AnalyticsEvents.paymentInitiated),
      containsPair('method', 'platform_pay'),
    );
    final succeeded = capturedFor(AnalyticsEvents.paymentSucceeded);
    expect(succeeded, containsPair('method', 'platform_pay'));
    expect(succeeded, containsPair('context', 'bid'));
    expect(succeeded, isNot(contains('amount')));
  });

  test('PayPal annulé : payment_cancelled, aucun échec', () async {
    when(
      () => gateway.confirmPayPal(any()),
    ).thenThrow(const PaymentCancelledException());
    final bloc = await openSheet();

    bloc.add(const PaymentSheetPayPalPressed());
    await bloc.stream.firstWhere((s) => s is PaymentSheetResolved);
    await settle();

    expect(
      capturedFor(AnalyticsEvents.paymentCancelled),
      containsPair('method', 'paypal'),
    );
    verifyNever(() => backend.capture(AnalyticsEvents.paymentFailed, any()));
    verifyNever(() => backend.capture(AnalyticsEvents.paymentSucceeded, any()));
  });

  test('refus PayPal : payment_failed reason declined', () async {
    when(
      () => gateway.confirmPayPal(any()),
    ).thenThrow(const PaymentConfirmationException('refusé'));
    final bloc = await openSheet();

    bloc.add(const PaymentSheetPayPalPressed());
    await bloc.stream.firstWhere((s) => s is PaymentSheetFailure);
    await settle();

    final failed = capturedFor(AnalyticsEvents.paymentFailed);
    expect(failed, containsPair('method', 'paypal'));
    expect(failed, containsPair('reason', 'declined'));
  });

  test('clé éphémère indisponible : reason card_unavailable', () async {
    when(() => repository.createEphemeralKey()).thenThrow(Exception('réseau'));
    final bloc = await openSheet();

    bloc.add(const PaymentSheetCardPressed());
    await bloc.stream.firstWhere((s) => s is PaymentSheetFailure);
    await settle();

    final failed = capturedFor(AnalyticsEvents.paymentFailed);
    expect(failed, containsPair('method', 'card'));
    expect(failed, containsPair('reason', 'card_unavailable'));
  });

  test('erreur non mappée : reason generic', () async {
    when(() => repository.createEphemeralKey()).thenAnswer(
      (_) async => const EphemeralKeyModel(
        ephemeralKeySecret: 'ek_test',
        customerId: 'cus_1',
      ),
    );
    when(
      () => gateway.initPaymentSheet(
        clientSecret: any(named: 'clientSecret'),
        customerId: any(named: 'customerId'),
        customerEphemeralKeySecret: any(named: 'customerEphemeralKeySecret'),
      ),
    ).thenAnswer((_) async {});
    when(() => gateway.presentPaymentSheet()).thenThrow(StateError('boom'));
    final bloc = await openSheet();

    bloc.add(const PaymentSheetCardPressed());
    await bloc.stream.firstWhere((s) => s is PaymentSheetFailure);
    await settle();

    expect(
      capturedFor(AnalyticsEvents.paymentFailed),
      containsPair('reason', 'generic'),
    );
  });

  test('sans consentement : aucun événement', () async {
    when(() => gateway.confirmPayPal(any())).thenAnswer((_) async {});
    final bloc = await openSheet(enabled: false);

    bloc.add(const PaymentSheetPayPalPressed());
    await bloc.stream.firstWhere((s) => s is PaymentSheetSuccess);
    await settle();

    verifyNever(() => backend.capture(any(), any()));
  });

  test('sans AnalyticsService injecté : la feuille fonctionne', () async {
    when(() => gateway.confirmPayPal(any())).thenAnswer((_) async {});
    final bloc = PaymentSheetBloc(
      gateway: gateway,
      repository: repository,
      config: config,
    )..add(const PaymentSheetStarted());
    await bloc.stream.firstWhere((s) => s is PaymentSheetResolved);

    bloc.add(const PaymentSheetPayPalPressed());
    await expectLater(bloc.stream, emitsThrough(isA<PaymentSheetSuccess>()));
  });

  test('contexte par défaut `unknown`', () {
    const bare = PaymentSheetConfig(
      clientSecret: 'pi_1_secret_x',
      amountEur: 10,
      paymentMethodTypes: [],
    );
    expect(bare.analyticsContext, 'unknown');
    expect(bare, isNot(config));
  });
}
