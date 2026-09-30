import 'package:dony/features/payments/presentation/stripe_onboarding_return.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(StripeOnboardingReturn.consume);

  test('rien de retenu → null (repli sur l\'écran par défaut)', () {
    expect(StripeOnboardingReturn.consume(), isNull);
  });

  test('route retenue rendue une seule fois, paramètres compris', () {
    StripeOnboardingReturn.remember('/payments/onboarding?entry=onboarding');

    expect(
      StripeOnboardingReturn.consume(),
      '/payments/onboarding?entry=onboarding',
    );
    expect(StripeOnboardingReturn.consume(), isNull);
  });

  test('la dernière ouverture l\'emporte', () {
    StripeOnboardingReturn.remember('/connect/onboarding/intro');
    StripeOnboardingReturn.remember('/payments/onboarding');

    expect(StripeOnboardingReturn.consume(), '/payments/onboarding');
  });
}
