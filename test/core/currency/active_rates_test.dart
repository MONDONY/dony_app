import 'package:dony/core/currency/active_rates.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(ActiveRates.resetForTest);

  group('ActiveRates — source serveur avec repli catalogue', () {
    test('sans chargement : repli sur la constante du catalogue', () {
      expect(
        ActiveRates.unitsPerEurFor(SupportedCurrency.usd),
        SupportedCurrency.usd.unitsPerEur,
      );
    });

    test('taux serveur chargé : il prime sur la constante', () {
      ActiveRates.setServerRates({'USD': 1.1642});

      expect(ActiveRates.unitsPerEurFor(SupportedCurrency.usd), 1.1642);
      // Les devises non couvertes gardent leur repli.
      expect(
        ActiveRates.unitsPerEurFor(SupportedCurrency.cad),
        SupportedCurrency.cad.unitsPerEur,
      );
    });

    test('taux corrompu (≤ 0) ou code hors catalogue : ignoré', () {
      ActiveRates.setServerRates({'USD': -1, 'GBP': 0, 'ZZZ': 2.0});

      expect(
        ActiveRates.unitsPerEurFor(SupportedCurrency.usd),
        SupportedCurrency.usd.unitsPerEur,
      );
      expect(
        ActiveRates.unitsPerEurFor(SupportedCurrency.gbp),
        SupportedCurrency.gbp.unitsPerEur,
      );
    });

    test('casse et espaces normalisés', () {
      ActiveRates.setServerRates({' usd ': 1.20});

      expect(ActiveRates.unitsPerEurFor(SupportedCurrency.usd), 1.20);
    });
  });

  group('consommateurs pricing — le taux serveur pilote les bornes', () {
    test('maxUnitPriceFor suit le taux serveur', () {
      ActiveRates.setServerRates({'USD': 2.0});

      // 500 EUR × 2.0 = 1000 $ au lieu de 540 $ à la constante 1.08.
      expect(maxUnitPriceFor(SupportedCurrency.usd), 1000);
    });

    test('priceFilterBoundsFor suit le taux serveur', () {
      ActiveRates.setServerRates({'XOF': 700});

      final b = priceFilterBoundsFor(SupportedCurrency.xof);
      // 3 × 700 = 2100 → 2000 ; 25 × 700 = 17 500 (arrondi 500).
      expect(b.min, 2000);
      expect(b.max, 17500);
    });

    test('quickPriceFilterOptionsFor suit le taux serveur', () {
      ActiveRates.setServerRates({'XOF': 700});

      // 6 × 700 = 4200 → 4000 ; 9 × 700 = 6300 → 6500.
      expect(quickPriceFilterOptionsFor(SupportedCurrency.xof), [4000, 6500]);
    });
  });
}
