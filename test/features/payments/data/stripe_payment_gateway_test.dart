import 'package:dony/features/payments/data/payment_gateway.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockStripePlatform extends Mock
    with MockPlatformInterfaceMixin
    implements StripePlatform {}

const _intent = PaymentIntent(
  id: 'pi_1',
  amount: 1200,
  created: '0',
  currency: 'eur',
  status: PaymentIntentsStatus.Succeeded,
  clientSecret: 'pi_1_secret',
  livemode: false,
  captureMethod: CaptureMethod.Manual,
  confirmationMethod: ConfirmationMethod.Automatic,
);

StripeException _stripeError(FailureCode code, {String? stripeErrorCode}) =>
    StripeException(
      error: LocalizedErrorMessage(
        code: code,
        stripeErrorCode: stripeErrorCode,
      ),
    );

void main() {
  // Une seule instance : `Stripe` mémorise sa plateforme au premier appel.
  final platform = _MockStripePlatform();

  setUpAll(() {
    StripePlatform.instance = platform;
    when(() => platform.updateSettingsLazily).thenReturn(true);
    Stripe.publishableKey = 'pk_test_123';
    registerFallbackValue(yadonyPaymentSheetParameters());
    registerFallbackValue(
      const PlatformPayConfirmParams.googlePay(
        googlePay: GooglePayParams(
          merchantCountryCode: 'FR',
          currencyCode: 'EUR',
        ),
      ),
    );
  });

  setUp(() {
    reset(platform);
    when(() => platform.updateSettingsLazily).thenReturn(true);
    when(
      () => platform.initialise(
        publishableKey: any(named: 'publishableKey'),
        stripeAccountId: any(named: 'stripeAccountId'),
        threeDSecureParams: any(named: 'threeDSecureParams'),
        merchantIdentifier: any(named: 'merchantIdentifier'),
        urlScheme: any(named: 'urlScheme'),
        setReturnUrlSchemeOnAndroid: any(named: 'setReturnUrlSchemeOnAndroid'),
      ),
    ).thenAnswer((_) async {});
    Stripe.instance.markNeedsSettings();
  });

  group('StripePaymentGateway', () {
    test('isPlatformPaySupported relaie la réponse du SDK', () async {
      when(
        () => platform.isPlatformPaySupported(
          params: any(named: 'params'),
          paymentRequestOptions: any(named: 'paymentRequestOptions'),
        ),
      ).thenAnswer((_) async => true);

      final gateway = StripePaymentGateway(publishableKey: 'pk_test_123');

      expect(await gateway.isPlatformPaySupported(), isTrue);
    });

    test('confirmPlatformPay confirme avec Google Pay hors iOS', () async {
      when(
        () => platform.platformPayConfirmPaymentIntent(
          clientSecret: any(named: 'clientSecret'),
          params: any(named: 'params'),
        ),
      ).thenAnswer((_) async => _intent);

      final gateway = StripePaymentGateway(publishableKey: 'pk_live_123');
      await gateway.confirmPlatformPay(
        clientSecret: 'pi_1_secret',
        amountEur: 12,
        currencyCode: 'xof',
      );

      final params =
          verify(
                () => platform.platformPayConfirmPaymentIntent(
                  clientSecret: 'pi_1_secret',
                  params: captureAny(named: 'params'),
                ),
              ).captured.single
              as PlatformPayConfirmParams;
      final googlePay = (params as PlatformPayConfirmParamsGooglePay).googlePay;
      expect(googlePay.currencyCode, 'XOF');
      expect(googlePay.merchantCountryCode, 'FR');
      expect(googlePay.testEnv, isFalse);
    });

    test('confirmPayPal confirme avec la méthode PayPal', () async {
      when(
        () => platform.confirmPayment(any(), any(), any()),
      ).thenAnswer((_) async => _intent);

      await StripePaymentGateway().confirmPayPal('pi_1_secret');

      final data =
          verify(
                () =>
                    platform.confirmPayment('pi_1_secret', captureAny(), any()),
              ).captured.single
              as PaymentMethodParams;
      expect(
        data,
        const PaymentMethodParams.payPal(
          paymentMethodData: PaymentMethodData(),
        ),
      );
    });

    test('initPaymentSheet transmet client, clé éphémère et retour', () async {
      when(
        () => platform.initPaymentSheet(any()),
      ).thenAnswer((_) async => null);

      await StripePaymentGateway().initPaymentSheet(
        clientSecret: 'pi_1_secret',
        customerId: 'cus_1',
        customerEphemeralKeySecret: 'ek_1',
      );

      final params =
          verify(() => platform.initPaymentSheet(captureAny())).captured.single
              as SetupPaymentSheetParameters;
      expect(params.paymentIntentClientSecret, 'pi_1_secret');
      expect(params.customerId, 'cus_1');
      expect(params.customerEphemeralKeySecret, 'ek_1');
      expect(params.returnURL, kStripeReturnUrl);
    });

    test(
      'presentPaymentSheet : annulation = PaymentCancelledException',
      () async {
        when(
          () => platform.presentPaymentSheet(options: any(named: 'options')),
        ).thenThrow(_stripeError(FailureCode.Canceled));

        await expectLater(
          StripePaymentGateway().presentPaymentSheet(),
          throwsA(isA<PaymentCancelledException>()),
        );
      },
    );

    test(
      'presentPaymentSheet : refus = PaymentConfirmationException',
      () async {
        when(
          () => platform.presentPaymentSheet(options: any(named: 'options')),
        ).thenThrow(
          _stripeError(FailureCode.Failed, stripeErrorCode: 'card_declined'),
        );

        await expectLater(
          StripePaymentGateway().presentPaymentSheet(),
          throwsA(
            isA<PaymentConfirmationException>()
                .having((e) => e.isFromStripe, 'isFromStripe', isTrue)
                .having((e) => e.stripeErrorCode, 'code', 'card_declined'),
          ),
        );
      },
    );

    test('presentPaymentSheet réussi : aucune exception', () async {
      when(
        () => platform.presentPaymentSheet(options: any(named: 'options')),
      ).thenAnswer((_) async => null);

      await expectLater(
        StripePaymentGateway().presentPaymentSheet(),
        completes,
      );
    });
  });

  test('PaymentConfirmationException construite par l’app : hors Stripe', () {
    const e = PaymentConfirmationException('Paiement refusé');
    expect(e.message, 'Paiement refusé');
    expect(e.isFromStripe, isFalse);
    expect(e.stripeCode, isNull);
  });
}
