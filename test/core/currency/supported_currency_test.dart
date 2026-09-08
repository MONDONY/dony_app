import 'package:dony/core/currency/supported_currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupportedCurrency', () {
    test('le catalogue porte les sept devises derivees d\'un pays', () {
      expect(
        SupportedCurrency.values.map((c) => c.code).toList(),
        containsAll(<String>['EUR', 'USD', 'CAD', 'GBP', 'CHF', 'XOF', 'XAF']),
      );
    });

    test('expose les devises initiales avec leur précision Stripe', () {
      expect(SupportedCurrency.usd.code, 'USD');
      expect(SupportedCurrency.cad.code, 'CAD');
      expect(SupportedCurrency.eur.code, 'EUR');
      expect(SupportedCurrency.gbp.code, 'GBP');
      expect(SupportedCurrency.chf.code, 'CHF');
      expect(SupportedCurrency.xof.minorUnit, 0);
      expect(SupportedCurrency.xaf.minorUnit, 0);
    });

    test(
      'accepte les codes API insensibles à la casse et refuse les autres',
      () {
        expect(SupportedCurrency.fromCode('cad'), SupportedCurrency.cad);
        expect(SupportedCurrency.fromCode('EUR'), SupportedCurrency.eur);
        expect(SupportedCurrency.fromCode('JPY'), isNull);
      },
    );

    test('expose le taux indicatif de chaque devise par rapport à EUR', () {
      expect(SupportedCurrency.eur.unitsPerEur, 1);
      expect(SupportedCurrency.usd.unitsPerEur, 1.08);
      expect(SupportedCurrency.cad.unitsPerEur, 1.47);
      expect(SupportedCurrency.gbp.unitsPerEur, 0.86);
      expect(SupportedCurrency.chf.unitsPerEur, 0.95);
      expect(SupportedCurrency.xof.unitsPerEur, 655.957);
      expect(SupportedCurrency.xaf.unitsPerEur, 655.957);
    });

    test(
      'isMobileMoneyEligible — seules XOF et XAF (zone CFA) sont éligibles',
      () {
        expect(SupportedCurrency.xof.isMobileMoneyEligible, isTrue);
        expect(SupportedCurrency.xaf.isMobileMoneyEligible, isTrue);
        expect(SupportedCurrency.eur.isMobileMoneyEligible, isFalse);
        expect(SupportedCurrency.usd.isMobileMoneyEligible, isFalse);
        expect(SupportedCurrency.cad.isMobileMoneyEligible, isFalse);
        expect(SupportedCurrency.gbp.isMobileMoneyEligible, isFalse);
        expect(SupportedCurrency.chf.isMobileMoneyEligible, isFalse);
      },
    );
  });
}
