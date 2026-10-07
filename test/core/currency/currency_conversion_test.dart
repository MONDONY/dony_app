import 'package:dony/core/currency/active_rates.dart';
import 'package:dony/core/currency/currency_conversion.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(ActiveRates.resetForTest);

  group('convertCurrencyAmount — même calcul que ExchangeRateService', () {
    double eurToXof(double amount) => convertCurrencyAmount(
      amount,
      from: SupportedCurrency.eur,
      fromUnitsPerEur: 1,
      to: SupportedCurrency.xof,
      toUnitsPerEur: 655.957,
    );

    test('EUR → XOF : arrondi à l\'unité, HALF_UP', () {
      expect(eurToXof(10), 6560); // 6 559,57
      expect(eurToXof(12), 7871); // 7 871,484
      expect(eurToXof(12.60), 8265); // 8 265,0582
    });

    test('XOF → EUR : pivot puis 2 décimales', () {
      final eur = convertCurrencyAmount(
        6560,
        from: SupportedCurrency.xof,
        fromUnitsPerEur: 655.957,
        to: SupportedCurrency.eur,
        toUnitsPerEur: 1,
      );
      expect(eur, 10.0);
    });

    test('croisé USD → CAD via le pivot EUR', () {
      final cad = convertCurrencyAmount(
        10,
        from: SupportedCurrency.usd,
        fromUnitsPerEur: 1.08,
        to: SupportedCurrency.cad,
        toUnitsPerEur: 1.47,
      );
      // 10 / 1,08 = 9,2592592593 ; × 1,47 = 13,6111… → 13,61
      expect(cad, 13.61);
    });

    test('même devise : montant inchangé', () {
      expect(
        convertCurrencyAmount(
          12.345,
          from: SupportedCurrency.eur,
          fromUnitsPerEur: 1,
          to: SupportedCurrency.eur,
          toUnitsPerEur: 1,
        ),
        12.345,
      );
    });
  });

  group('roundHalfUp', () {
    test('la demie monte, malgré l\'erreur binaire des doubles', () {
      expect(roundHalfUp(1.005, 2), 1.01);
      expect(roundHalfUp(2.5, 0), 3);
      expect(roundHalfUp(2.49, 0), 2);
    });

    test('valeurs négatives : symétrique (s\'éloigne de zéro)', () {
      expect(roundHalfUp(-2.5, 0), -3);
    });
  });

  group('convertWithServerRates', () {
    test('taux serveur absents : null (pas de repli catalogue)', () {
      expect(
        convertWithServerRates(
          10,
          from: SupportedCurrency.eur,
          to: SupportedCurrency.xof,
        ),
        isNull,
      );
    });

    test('taux serveur chargés : conversion', () {
      ActiveRates.setServerRates({'XOF': 655.957});
      expect(
        convertWithServerRates(
          10,
          from: SupportedCurrency.eur,
          to: SupportedCurrency.xof,
        ),
        6560,
      );
    });

    test('même devise : montant inchangé, même sans taux', () {
      expect(
        convertWithServerRates(
          7,
          from: SupportedCurrency.xof,
          to: SupportedCurrency.xof,
        ),
        7,
      );
    });
  });

  group('ActiveRates.serverUnitsPerEurFor', () {
    test('EUR vaut toujours 1, les autres null avant chargement', () {
      expect(ActiveRates.serverUnitsPerEurFor(SupportedCurrency.eur), 1);
      expect(ActiveRates.serverUnitsPerEurFor(SupportedCurrency.usd), isNull);
    });
  });
}
