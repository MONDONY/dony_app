import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

/// La devise borne les moyens proposables sur une demande de colis, comme
/// `CurrencyPaymentRails` côté backend.
void main() {
  group('PaymentMethod.selectableIn', () {
    test('zone CFA : espèces seules, jamais la carte', () {
      expect(PaymentMethod.selectableIn(SupportedCurrency.xof), [
        PaymentMethod.cash,
      ]);
      expect(PaymentMethod.selectableIn(SupportedCurrency.xaf), [
        PaymentMethod.cash,
      ]);
    });

    test('hors zone CFA : carte puis espèces', () {
      for (final c in [
        SupportedCurrency.eur,
        SupportedCurrency.usd,
        SupportedCurrency.cad,
      ]) {
        expect(PaymentMethod.selectableIn(c), [
          PaymentMethod.stripe,
          PaymentMethod.cash,
        ], reason: c.code);
      }
    });
  });
}
