import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/package_request/bloc/package_request_form_state.dart';
import 'package:dony/features/package_request/presentation/screens/sender/create_wizard/wizard_currency.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../../helpers/currency_test_doubles.dart';

void main() {
  group('resolveWizardCurrency (FLUTTER-HB)', () {
    test('la devise du formulaire prime sur le repli et la devise active', () {
      registerCurrencyPreference('USD');
      expect(
        resolveWizardCurrency(
          const PackageRequestFormState(currency: SupportedCurrency.xof),
          fallback: SupportedCurrency.usd,
        ),
        SupportedCurrency.xof,
      );
    });

    test('sans devise de formulaire : repli fourni par l\'écran', () {
      registerCurrencyPreference('USD');
      expect(
        resolveWizardCurrency(
          const PackageRequestFormState(),
          fallback: SupportedCurrency.xaf,
        ),
        SupportedCurrency.xaf,
      );
    });

    test('sans repli : devise active en cache', () {
      registerCurrencyPreference('USD');
      expect(
        resolveWizardCurrency(const PackageRequestFormState()),
        SupportedCurrency.usd,
      );
    });

    test('rien de connu : euro', () {
      expect(
        resolveWizardCurrency(const PackageRequestFormState()),
        SupportedCurrency.eur,
      );
    });
  });
}
