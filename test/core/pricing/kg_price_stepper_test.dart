import 'package:dony/core/currency/active_rates.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/pricing/kg_price_stepper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(ActiveRates.resetForTest);

  group('kgPriceStepperBoundsFor', () {
    test('EUR : 3 à 25 €, pas de 1 €', () {
      final b = kgPriceStepperBoundsFor(SupportedCurrency.eur);
      expect(b.min, 3);
      expect(b.max, 25);
      expect(b.step, 1);
    });

    test('XOF : plancher au premier repère CFA (1 000), pas de 500', () {
      final b = kgPriceStepperBoundsFor(SupportedCurrency.xof);
      expect(b.min, KgPriceReference.cfa.presets.first);
      expect(
        b.min,
        greaterThanOrEqualTo(minUnitPriceFor(SupportedCurrency.xof)),
      );
      expect(b.step, 500);
      expect(b.max, priceFilterBoundsFor(SupportedCurrency.xof).max);
    });

    test('jamais sous le plancher ni au-dessus du plafond du serveur', () {
      for (final c in SupportedCurrency.values) {
        final b = kgPriceStepperBoundsFor(c);
        expect(b.min, greaterThanOrEqualTo(minUnitPriceFor(c)), reason: c.code);
        expect(b.max, lessThanOrEqualTo(maxUnitPriceFor(c)), reason: c.code);
        expect(b.min, lessThan(b.max), reason: c.code);
      }
    });
  });

  group('stepKgPrice / clampKgPrice', () {
    const eur = (min: 3.0, max: 25.0, step: 1.0);

    test('un pas dans chaque sens', () {
      expect(stepKgPrice(8, eur, up: true), 9);
      expect(stepKgPrice(8, eur, up: false), 7);
    });

    test('prix hors grille : multiple du pas le plus proche dans le sens', () {
      expect(stepKgPrice(8.5, eur, up: true), 9);
      expect(stepKgPrice(8.5, eur, up: false), 8);
    });

    test('bornes', () {
      expect(stepKgPrice(3, eur, up: false), 3);
      expect(stepKgPrice(25, eur, up: true), 25);
      expect(stepKgPrice(30, eur, up: false), 25);
      expect(clampKgPrice(1, eur), 3);
      expect(clampKgPrice(40, eur), 25);
      expect(clampKgPrice(10, eur), 10);
    });

    test('XOF : pas de 500', () {
      const xof = (min: 1000.0, max: 16500.0, step: 500.0);
      expect(stepKgPrice(2000, xof, up: true), 2500);
      expect(stepKgPrice(2200, xof, up: false), 2000);
    });
  });
}
