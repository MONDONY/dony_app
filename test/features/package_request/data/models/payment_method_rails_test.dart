import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:flutter_test/flutter_test.dart';

/// La devise borne les moyens proposables sur une demande de colis, comme
/// `CurrencyPaymentRails` côté backend.
void main() {
  group('PaymentMethod.selectableIn', () {
    test('zone CFA : mobile money puis espèces, jamais la carte', () {
      for (final c in [SupportedCurrency.xof, SupportedCurrency.xaf]) {
        expect(PaymentMethod.selectableIn(c), [
          PaymentMethod.mobileMoney,
          PaymentMethod.cash,
        ], reason: c.code);
      }
    });

    test('hors zone CFA : carte puis espèces, jamais le mobile money', () {
      for (final c in [
        SupportedCurrency.eur,
        SupportedCurrency.usd,
        SupportedCurrency.cad,
        SupportedCurrency.gbp,
        SupportedCurrency.chf,
      ]) {
        expect(PaymentMethod.selectableIn(c), [
          PaymentMethod.stripe,
          PaymentMethod.cash,
        ], reason: c.code);
      }
    });

    test('toute devise supportée propose au moins les espèces', () {
      for (final c in SupportedCurrency.values) {
        expect(
          PaymentMethod.selectableIn(c),
          contains(PaymentMethod.cash),
          reason: c.code,
        );
      }
    });
  });

  test(
    'canonicalOrder : carte, mobile money, espèces, puis les rails retirés',
    () {
      expect(PaymentMethod.canonicalOrder, [
        PaymentMethod.stripe,
        PaymentMethod.mobileMoney,
        PaymentMethod.cash,
        PaymentMethod.wave,
        PaymentMethod.orangeMoney,
      ]);
    },
  );
}
