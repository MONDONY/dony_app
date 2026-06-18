import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:dony/features/payments/data/stripe_payment_sheet_params.dart';

void main() {
  test('donyPaymentSheetParams configure wallets + clientSecret', () {
    final params = donyPaymentSheetParams('pi_secret_123');

    expect(params.paymentIntentClientSecret, 'pi_secret_123');
    expect(params.merchantDisplayName, 'dony');
    expect(params.applePay?.merchantCountryCode, 'FR');
    expect(params.googlePay?.merchantCountryCode, 'FR');
    // testEnv dérivé de la clé : en test (pas de dart-define) → false
    expect(params.googlePay?.testEnv, false);
  });
}
