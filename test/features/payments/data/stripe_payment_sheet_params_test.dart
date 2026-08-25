import 'package:dony/features/payments/data/stripe_payment_sheet_params.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'donyPaymentSheetParams configure wallets + clientSecret + returnURL',
    () {
      final params = donyPaymentSheetParams('pi_secret_123');

      expect(params.paymentIntentClientSecret, 'pi_secret_123');
      expect(params.merchantDisplayName, 'Yadony');
      expect(params.returnURL, 'yadony://stripe/payment-return');
      expect(params.applePay?.merchantCountryCode, 'FR');
      expect(params.googlePay?.merchantCountryCode, 'FR');
    },
  );

  test('testEnv = false pour une clé live (pk_live)', () {
    final params = donyPaymentSheetParams(
      's',
      stripePublishableKey: 'pk_live_abc',
    );
    expect(params.googlePay?.testEnv, false);
  });

  test('testEnv = true pour une clé sandbox (pk_test)', () {
    final params = donyPaymentSheetParams(
      's',
      stripePublishableKey: 'pk_test_abc',
    );
    expect(params.googlePay?.testEnv, true);
  });
}
