import 'package:dony/core/currency/supported_currency.dart';
import 'package:flutter/foundation.dart';
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

    group('fromCodeOrDefault', () {
      late List<String> printed;
      late DebugPrintCallback original;

      setUp(() {
        SupportedCurrency.resetUnknownCodeReportsForTest();
        printed = <String>[];
        original = debugPrint;
        debugPrint = (String? message, {int? wrapWidth}) {
          if (message != null) printed.add(message);
        };
      });

      tearDown(() {
        debugPrint = original;
        SupportedCurrency.resetUnknownCodeReportsForTest();
      });

      test('code connu → la devise, sans avertissement', () {
        expect(
          SupportedCurrency.fromCodeOrDefault('xof'),
          SupportedCurrency.xof,
        );
        expect(printed, isEmpty);
      });

      test('code absent ou vide → euro, en silence', () {
        expect(
          SupportedCurrency.fromCodeOrDefault(null),
          SupportedCurrency.eur,
        );
        expect(
          SupportedCurrency.fromCodeOrDefault('  '),
          SupportedCurrency.eur,
        );
        expect(printed, isEmpty);
      });

      test('code hors catalogue → euro, signalé une seule fois par code', () {
        expect(
          SupportedCurrency.fromCodeOrDefault('MAD'),
          SupportedCurrency.eur,
        );
        expect(
          SupportedCurrency.fromCodeOrDefault('mad '),
          SupportedCurrency.eur,
        );
        expect(SupportedCurrency.symbolOf('MAD'), '€');
        expect(printed, hasLength(1));
        expect(printed.single, contains('Devise hors catalogue'));
        expect(printed.single, contains('MAD'));

        expect(
          SupportedCurrency.fromCodeOrDefault('GNF'),
          SupportedCurrency.eur,
        );
        expect(printed, hasLength(2));
        expect(printed.last, contains('GNF'));
      });
    });

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
