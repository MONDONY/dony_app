import 'package:dony/core/currency/active_rates.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repères de prix au kilo par devise. Sans conteneur d'injection,
/// `ActiveCurrency.current` vaut null : [KgPriceReference.active] retombe sur
/// l'euro, ce que le dernier test vérifie.
void main() {
  tearDown(ActiveRates.resetForTest);

  group('KgPriceReference.forCurrency', () {
    test('EUR : repères historiques inchangés', () {
      final ref = KgPriceReference.forCurrency(SupportedCurrency.eur);
      expect(ref.presets, [5, 6, 7, 8]);
      expect(ref.marketMedian, 8);
      expect(ref.minReasonable, 5);
      expect(ref.maxReasonable, 15);
    });

    test('XOF : table dédiée, pas une conversion du barème euro', () {
      // 5 €/kg convertis feraient 3 280 F CFA, hors des tarifs pratiqués.
      final ref = KgPriceReference.forCurrency(SupportedCurrency.xof);
      expect(ref.presets, [1000, 1500, 2000, 3000]);
      expect(ref.marketMedian, 2000);
      expect(ref.minReasonable, 1000);
      expect(ref.maxReasonable, 5000);
    });

    test('XAF : même table que XOF', () {
      expect(
        KgPriceReference.forCurrency(SupportedCurrency.xaf),
        same(KgPriceReference.forCurrency(SupportedCurrency.xof)),
      );
    });

    test('USD : barème euro à l\'échelle du taux, arrondi au demi', () {
      // Taux catalogue 1,08 : 5,4 → 5,5 ; 6,48 → 6,5 ; 7,56 → 7,5 ; 8,64 → 8,5.
      final ref = KgPriceReference.forCurrency(SupportedCurrency.usd);
      expect(ref.presets, [5.5, 6.5, 7.5, 8.5]);
      expect(ref.marketMedian, 8.5);
      expect(ref.minReasonable, 5.5);
      expect(ref.maxReasonable, 16);
    });

    test('devise scalée : suit le taux serveur quand il est chargé', () {
      ActiveRates.setServerRates({'USD': 2});
      final ref = KgPriceReference.forCurrency(SupportedCurrency.usd);
      expect(ref.presets, [10, 12, 14, 16]);
      expect(ref.maxReasonable, 30);
    });

    test('CFA : insensible au taux serveur', () {
      ActiveRates.setServerRates({'XOF': 700});
      expect(KgPriceReference.forCurrency(SupportedCurrency.xof).presets, [
        1000,
        1500,
        2000,
        3000,
      ]);
    });
  });

  group('KgPriceReference.forCode', () {
    test('code XOF → table CFA', () {
      expect(KgPriceReference.forCode('xof').presets.first, 1000);
    });

    test('code absent ou inconnu → repli euro', () {
      expect(KgPriceReference.forCode(null).presets, [5, 6, 7, 8]);
      expect(KgPriceReference.forCode('ZZZ').presets, [5, 6, 7, 8]);
    });
  });

  group('fourchette raisonnable', () {
    test('XOF : 500 trop bas, 2 000 dedans, 6 000 trop élevé', () {
      const ref = KgPriceReference.cfa;
      expect(ref.isTooLow(500), isTrue);
      expect(ref.isTooLow(1000), isFalse);
      expect(ref.isTooHigh(2000), isFalse);
      expect(ref.isTooHigh(5000), isFalse);
      expect(ref.isTooHigh(6000), isTrue);
    });
  });

  test('active : repli euro sans devise active', () {
    expect(KgPriceReference.active, same(KgPriceReference.eur));
  });
}
