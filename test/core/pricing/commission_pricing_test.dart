import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_pricing.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/commission_grid_test_doubles.dart';

void main() {
  setUp(() => setDonyCommissionRate(0.05));
  tearDown(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  group('senderPriceForNet', () {
    test(
      "sans grille : 35 € → 1,75 € de frais, 36,75 €, comme aujourd'hui",
      () {
        final price = senderPriceForNet(35, 'EUR');

        expect(price.net, 35);
        expect(price.commission, 1.75);
        expect(price.gross, 36.75);
        expect(price.minimumApplied, isFalse);
        expect(price.fromGrid, isFalse);
      },
    );

    test('sans grille : le taux hérité est arrondi au centime', () {
      // 33,33 × 0,05 = 1,6665 → 1,67 (HALF_UP), brut 35,00.
      final price = senderPriceForNet(33.33, 'EUR');

      expect(price.commission, 1.67);
      expect(price.gross, 35.00);
    });

    test('sans grille : legacyRate remplace le taux courant', () {
      final price = senderPriceForNet(30, 'EUR', legacyRate: 0.12);

      expect(price.commission, 3.60);
      expect(price.gross, 33.60);
      expect(price.fromGrid, isFalse);
    });

    test('grille : 5 € → 1,00 € (minimum), 6,00 €', () {
      useTestCommissionGrid();

      final price = senderPriceForNet(5, 'EUR');

      expect(price.net, 5);
      expect(price.commission, 1.00);
      expect(price.gross, 6.00);
      expect(price.minimumApplied, isTrue);
      expect(price.fromGrid, isTrue);
    });

    test('grille : 650 F CFA de minimum sur 5 000 XOF', () {
      useTestCommissionGrid();

      final price = senderPriceForNet(5000, 'XOF');

      expect(price.commission, 650);
      expect(price.gross, 5650);
      expect(price.minimumApplied, isTrue);
      expect(price.fromGrid, isTrue);
    });

    test(
      'grille passée en paramètre : prioritaire sur la grille en vigueur',
      () {
        // Aucune grille en vigueur, mais une grille figée fournie.
        final price = senderPriceForNet(5, 'EUR', grid: testGrid757());

        expect(price.gross, 6.00);
        expect(price.fromGrid, isTrue);
      },
    );

    test('legacy: true force le taux unique malgré la grille', () {
      useTestCommissionGrid();

      final price = senderPriceForNet(35, 'EUR', legacy: true);

      expect(price.commission, 1.75);
      expect(price.gross, 36.75);
      expect(price.fromGrid, isFalse);
    });

    test('minimum absent pour la devise : repli sur le taux unique', () {
      useTestCommissionGrid(
        CommissionGrid(
          id: 'grid-xof-only',
          effectiveFrom: DateTime.utc(2026, 10),
          tiers: const [CommissionTier(fromEur: 0, rate: 0.07)],
          minimums: const {'XOF': 650},
        ),
      );

      final price = senderPriceForNet(35, 'EUR');

      expect(price.commission, 1.75);
      expect(price.gross, 36.75);
      expect(price.fromGrid, isFalse);
    });

    test('réductions transmises au calcul de grille', () {
      useTestCommissionGrid();

      // 200 € : grille 7 + 6 = 13 €, taux spécial 2 % → 4 €.
      final price = senderPriceForNet(
        200,
        'EUR',
        reductions: const CommissionReductions(overrideRate: 0.02),
      );

      expect(price.commission, 4.00);
      expect(price.gross, 204.00);
    });

    test('devise absente : repli EUR, sans exception', () {
      useTestCommissionGrid();

      final price = senderPriceForNet(5, null);

      expect(price.gross, 6.00);
    });

    test('net nul : SenderPrice à zéro, sans exception', () {
      useTestCommissionGrid();

      for (final net in [0.0, -3.0, 0.001]) {
        final price = senderPriceForNet(net, 'EUR');
        expect(price.net, 0);
        expect(price.commission, 0);
        expect(price.gross, 0);
        expect(price.minimumApplied, isFalse);
      }
      expect(senderPriceForNet(0, 'EUR', legacy: true).gross, 0);
    });
  });

  group('netForSenderGross', () {
    test(
      'netForSenderGross(21.40) vaut 20,00 sous grille ; 1,00 € lève BudgetBelowCommissionMinimumException',
      () {
        useTestCommissionGrid();

        expect(netForSenderGross(21.40, 'EUR'), 20.00);
        expect(
          () => netForSenderGross(1.00, 'EUR'),
          throwsA(isA<BudgetBelowCommissionMinimumException>()),
        );
      },
    );

    test('sans grille : brut / (1 + taux)', () {
      expect(netForSenderGross(21.00, 'EUR'), closeTo(20.00, 1e-9));
    });

    test('legacy: true ignore la grille', () {
      useTestCommissionGrid();

      expect(netForSenderGross(21.00, 'EUR', legacy: true), closeTo(20, 1e-9));
    });

    test('minimum absent pour la devise : repli sur le taux unique', () {
      useTestCommissionGrid(
        CommissionGrid(
          id: 'grid-xof-only',
          effectiveFrom: DateTime.utc(2026, 10),
          tiers: const [CommissionTier(fromEur: 0, rate: 0.07)],
          minimums: const {'XOF': 650},
        ),
      );

      expect(netForSenderGross(21.00, 'EUR'), closeTo(20, 1e-9));
    });
  });

  group('listUnitPrice', () {
    test('listUnitPrice(8) vaut 8 sous grille et 8,40 sans', () {
      expect(listUnitPrice(8, 'EUR'), closeTo(8.40, 1e-9));

      useTestCommissionGrid();
      expect(listUnitPrice(8, 'EUR'), 8);
    });

    test('grille sans minimum pour la devise : taux unique, comme le suffixe '
        'et senderPriceForNet', () {
      useTestCommissionGrid(
        CommissionGrid(
          id: 'grid-eur-only',
          effectiveFrom: DateTime.utc(2026, 10),
          tiers: const [CommissionTier(fromEur: 0, rate: 0.07)],
          minimums: const {'EUR': 1.00},
        ),
      );
      expect(listUnitPrice(8, 'EUR'), 8);
      expect(listUnitPrice(8, 'USD'), closeTo(8.40, 1e-9));
      // Devise absente ou inconnue : repli EUR, comme formatPriceIn.
      expect(listUnitPrice(8, null), 8);
    });
  });

  group('halfMinorUnit', () {
    test('0,005 en euros, 0,5 en francs CFA', () {
      expect(halfMinorUnit(SupportedCurrency.eur), closeTo(0.005, 1e-12));
      expect(
        halfMinorUnit(SupportedCurrency.fromCodeOrDefault('XOF')),
        closeTo(0.5, 1e-12),
      );
    });
  });

  group('commissionMinimumFor / commissionGridActive', () {
    test('commissionMinimumFor : 1 en EUR, 650 en XOF, null sans grille', () {
      expect(commissionMinimumFor('EUR'), isNull);
      expect(commissionGridActive, isFalse);

      useTestCommissionGrid();
      expect(commissionMinimumFor('EUR'), 1);
      expect(commissionMinimumFor('xof'), 650);
      expect(commissionMinimumFor(null), 1);
      expect(commissionGridActive, isTrue);
    });
  });

  group('flatRateGross', () {
    test('net × (1 + taux unique), sans arrondi, même produit qu\'avant', () {
      // setUp : taux 0,05.
      const weight = 1.15;
      const price = 8.5;
      expect(flatRateGross(weight * price), weight * price * (1 + 0.05));
      setDonyCommissionRate(0.12);
      expect(flatRateGross(10), closeTo(11.2, 1e-12));
      // Inverse exact du repli de netForSenderGross au taux unique.
      expect(netForSenderGross(11.2, 'EUR', legacy: true), 11.2 / (1 + 0.12));
    });
  });
}
