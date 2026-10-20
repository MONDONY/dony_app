import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Identifiant de la grille de référence des tests.
const kTestGridId = 'grid-757';

/// Grille de la fixture `test/fixtures/commission/vectors.json` (7 % jusqu'à
/// 100 €, 6 % jusqu'à 300 €, 5 % au-delà, minimums par devise).
CommissionGrid testGrid757() => CommissionGrid(
  id: kTestGridId,
  effectiveFrom: DateTime.utc(2026, 10),
  tiers: const [
    CommissionTier(fromEur: 0, rate: 0.07),
    CommissionTier(fromEur: 100, rate: 0.06),
    CommissionTier(fromEur: 300, rate: 0.05),
  ],
  minimums: const {
    'EUR': 1.00,
    'XOF': 650,
    'XAF': 650,
    'USD': 1.10,
    'CAD': 1.50,
    'GBP': 0.90,
    'CHF': 0.95,
  },
);

/// Pose [grid] (par défaut [testGrid757]) comme grille en vigueur et remet le
/// magasin à zéro en fin de test.
void useTestCommissionGrid([CommissionGrid? grid]) {
  CommissionGridStore.setConfig(
    CommissionGridConfig(current: grid ?? testGrid757()),
  );
  addTearDown(CommissionGridStore.reset);
}
