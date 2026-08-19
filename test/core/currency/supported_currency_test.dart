import 'package:dony/core/currency/supported_currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupportedCurrency', () {
    test('le catalogue est fermé à EUR, XOF, XAF depuis le 2026-08-19', () {
      // USD/CAD/GBP/CHF retirés (zéro compte réel en prod à cette date) — voir
      // docs/specs/2026-08-19-plan-implementation-multidevise.md, lot 1.
      expect(SupportedCurrency.values, [
        SupportedCurrency.eur,
        SupportedCurrency.xof,
        SupportedCurrency.xaf,
      ]);
    });

    test('expose les devises avec leur précision Stripe', () {
      expect(SupportedCurrency.eur.code, 'EUR');
      expect(SupportedCurrency.eur.minorUnit, 2);
      expect(SupportedCurrency.xof.minorUnit, 0);
      expect(SupportedCurrency.xaf.minorUnit, 0);
    });

    test(
      'accepte les codes API insensibles à la casse et refuse les autres',
      () {
        expect(SupportedCurrency.fromCode('xaf'), SupportedCurrency.xaf);
        expect(SupportedCurrency.fromCode('EUR'), SupportedCurrency.eur);
        expect(SupportedCurrency.fromCode('JPY'), isNull);
      },
    );

    test('un code retiré du catalogue (ex. usd) retombe sur EUR', () {
      expect(SupportedCurrency.fromCode('USD'), isNull);
      expect(SupportedCurrency.fromCodeOrDefault('USD'), SupportedCurrency.eur);
    });

    test('expose le taux indicatif de chaque devise par rapport à EUR', () {
      expect(SupportedCurrency.eur.unitsPerEur, 1);
      // Parité fixe avec l'euro, fixée par traité : ce n'est pas une
      // estimation de marché et la valeur ne dérive pas.
      expect(SupportedCurrency.xof.unitsPerEur, 655.957);
      expect(SupportedCurrency.xaf.unitsPerEur, 655.957);
    });
  });
}
