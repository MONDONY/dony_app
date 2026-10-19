import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/package_request/data/package_request_limits.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/commission_grid_test_doubles.dart';

/// Fix post-revue Tâche 13 : les bornes de budget colis reproduisaient
/// exactement le bug corrigé côté trajet (`maxUnitPriceFor`,
/// `dony_pricing_currency_test.dart`) — des constantes figées en euros
/// (1..560) comparées telles quelles à un montant saisi dans N'IMPORTE
/// QUELLE devise, y compris XOF/XAF où 1..560 unités valent ~0,0015 à
/// 0,85 €. Ces tests sont le pendant, côté demande de colis, de
/// `maxUnitPriceFor — suit la devise DE L'ANNONCE, pas celle du profil`.
void main() {
  group('minBudgetFor / maxBudgetFor — suivent la devise choisie', () {
    test('EUR : bornes de référence inchangées (1..560)', () {
      expect(PackageRequestLimits.minBudgetFor(SupportedCurrency.eur), 1.0);
      expect(PackageRequestLimits.maxBudgetFor(SupportedCurrency.eur), 560.0);
    });

    test('USD : mise à l\'échelle avec deux décimales', () {
      expect(
        PackageRequestLimits.minBudgetFor(SupportedCurrency.usd),
        1.0 * 1.08,
      );
      expect(
        PackageRequestLimits.maxBudgetFor(SupportedCurrency.usd),
        560.0 * 1.08,
      );
    });

    test('XOF : mise à l\'échelle puis arrondie au franc (zéro décimale)', () {
      // 560 * 655.957 = 367335.92 → arrondi au franc inférieur.
      expect(
        PackageRequestLimits.maxBudgetFor(SupportedCurrency.xof),
        367335.0,
      );
      // 1 * 655.957 = 655.957 → arrondi au franc inférieur.
      expect(PackageRequestLimits.minBudgetFor(SupportedCurrency.xof), 655.0);
    });
  });

  group('isBudgetValid — un montant refusé dans une devise peut être '
      'valide dans une autre', () {
    // Cœur du fix : c'est exactement le scénario que le sélecteur de devise
    // (Tâche 13) rend maintenant possible — publier une demande en XOF.
    // 700 : au-delà du plafond EUR (560), mais toujours au-delà du plancher
    // XOF mis à l'échelle (655) — invalide dans les deux devises pour des
    // raisons opposées serait un mauvais choix de valeur ; 700 isole bien
    // le seul effet du plafond.
    test('700 est refusé en EUR (au-delà du plafond de 560)', () {
      expect(
        PackageRequestLimits.isBudgetValid(700, SupportedCurrency.eur),
        isFalse,
      );
    });

    test('700 est accepté en XOF (au-dessus du plancher, sous le plafond '
        'mis à l\'échelle)', () {
      expect(
        PackageRequestLimits.isBudgetValid(700, SupportedCurrency.xof),
        isTrue,
      );
    });

    test('un budget nul est toujours refusé, quelle que soit la devise', () {
      expect(
        PackageRequestLimits.isBudgetValid(null, SupportedCurrency.eur),
        isFalse,
      );
      expect(
        PackageRequestLimits.isBudgetValid(null, SupportedCurrency.xof),
        isFalse,
      );
    });

    test('un budget sous le plancher XOF (ex. 10) est refusé', () {
      // Plancher XOF = 655 : 10 XOF ne rémunère personne, exactement la même
      // garde que le plancher EUR de 1.
      expect(
        PackageRequestLimits.isBudgetValid(10, SupportedCurrency.xof),
        isFalse,
      );
    });
  });

  // Commission par paliers : un budget qui ne couvre pas les frais de service
  // minimum de la grille est refusé par le back (422
  // `budget-below-commission-minimum`), le formulaire le refuse avant.
  group('isBudgetValid — frais de service minimum de la grille', () {
    test('1,00 € : faux sous grille (le minimum EUR vaut 1,00 €)', () {
      useTestCommissionGrid();
      expect(
        PackageRequestLimits.isBudgetValid(1.0, SupportedCurrency.eur),
        isFalse,
      );
      expect(
        PackageRequestLimits.isBelowCommissionMinimum(
          1.0,
          SupportedCurrency.eur,
        ),
        isTrue,
      );
    });

    test('1,00 € : vrai sans grille (taux unique, comportement actuel)', () {
      expect(
        PackageRequestLimits.isBudgetValid(1.0, SupportedCurrency.eur),
        isTrue,
      );
      expect(
        PackageRequestLimits.isBelowCommissionMinimum(
          1.0,
          SupportedCurrency.eur,
        ),
        isFalse,
      );
    });

    test('1,01 € : vrai sous grille (net 0,01 €, frais 1,00 €)', () {
      useTestCommissionGrid();
      expect(
        PackageRequestLimits.isBudgetValid(1.01, SupportedCurrency.eur),
        isTrue,
      );
      expect(
        PackageRequestLimits.netForBudget(1.01, SupportedCurrency.eur),
        closeTo(0.01, 1e-9),
      );
    });

    test('la grille passée en paramètre prime sur la grille en vigueur', () {
      // Aucune grille en vigueur, mais la grille figée de la demande éditée.
      expect(
        PackageRequestLimits.isBudgetValid(
          1.0,
          SupportedCurrency.eur,
          grid: testGrid757(),
        ),
        isFalse,
      );
    });

    test('hors bornes : refusé sans être compté comme sous le minimum', () {
      useTestCommissionGrid();
      expect(
        PackageRequestLimits.isBelowCommissionMinimum(
          600,
          SupportedCurrency.eur,
        ),
        isFalse,
      );
      expect(
        PackageRequestLimits.isBelowCommissionMinimum(
          null,
          SupportedCurrency.eur,
        ),
        isFalse,
      );
    });

    test('XOF : le plancher 655 F CFA couvre le minimum de 650', () {
      useTestCommissionGrid();
      // Plancher XOF des bornes : 655. Net 5 → frais 650 (minimum) → brut 655.
      expect(
        PackageRequestLimits.isBudgetValid(655, SupportedCurrency.xof),
        isTrue,
      );
      expect(
        PackageRequestLimits.isBudgetValid(700, SupportedCurrency.xof),
        isTrue,
      );
    });
  });
}
