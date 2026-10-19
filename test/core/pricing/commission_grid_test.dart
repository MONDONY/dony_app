import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CommissionGrid gridWith(String effectiveFrom) => CommissionGrid.fromJson({
    'gridId': 'g1',
    'effectiveFrom': effectiveFrom,
    'tiers': [
      {'fromEur': 100, 'rate': 0.06},
      {'fromEur': 0, 'rate': 0.07},
      {'fromEur': 300, 'rate': 0.05},
    ],
    'minimums': {'EUR': 1.00, 'XOF': 650},
  });

  final grid = gridWith('2026-11-20T09:00:00');

  group('CommissionGrid.fromJson', () {
    test('lit une date sans fuseau comme UTC', () {
      final g = CommissionGrid.fromJson({
        'gridId': 'g1',
        'effectiveFrom': '2026-11-20T09:00:00',
        'tiers': [
          {'fromEur': 100, 'rate': 0.06},
          {'fromEur': 0, 'rate': 0.07},
        ],
        'minimums': {'EUR': 1.00, 'XOF': 650},
      });
      expect(g.id, 'g1');
      expect(g.effectiveFrom, DateTime.utc(2026, 11, 20, 9));
      expect(g.effectiveFrom.isUtc, isTrue);
      expect(g.tiers.first.fromEur, 0); // triées
      expect(g.tiers.first.rate, 0.07);
      expect(g.minimumFor('XOF'), 650);
      expect(g.minimumFor('xof'), 650);
      expect(g.minimumFor('GBP'), isNull);
    });

    test('garde un suffixe Z ou un décalage explicite', () {
      final z = gridWith('2026-11-20T09:00:00Z').effectiveFrom;
      expect(z, DateTime.utc(2026, 11, 20, 9));
      expect(z.isUtc, isTrue);
      final offset = gridWith('2026-11-20T10:00:00+01:00').effectiveFrom;
      expect(offset, DateTime.utc(2026, 11, 20, 9));
      expect(offset.isUtc, isTrue);
      expect(
        gridWith('2026-11-20T09:00:00.123456').effectiveFrom,
        DateTime.utc(2026, 11, 20, 9, 0, 0, 123, 456),
      );
    });

    test('accepte des nombres écrits en chaînes et des clés en minuscules', () {
      final g = CommissionGrid.fromJson({
        'gridId': 'g2',
        'effectiveFrom': '2026-01-01T00:00:00Z',
        'tiers': [
          {'fromEur': '0', 'rate': '0.07'},
        ],
        'minimums': {'eur': '1.00'},
      });
      expect(g.tiers.single.rate, 0.07);
      expect(g.minimumFor('EUR'), 1.0);
    });
  });

  group('computeCommission', () {
    test('refuse un net nul', () {
      expect(() => computeCommission(0, 'EUR', grid), throwsArgumentError);
      expect(() => computeCommission(0.004, 'EUR', grid), throwsArgumentError);
      expect(() => computeCommission(-3, 'EUR', grid), throwsArgumentError);
    });

    test('taux JSON 0.07 lu sans erreur flottante : 7,50 € → 1,00 € minimum, '
        '15,00 € → 1,05 €', () {
      final small = computeCommission(7.5, 'EUR', grid);
      expect(small.commission, 1.0);
      expect(small.minimumApplied, isTrue);
      final big = computeCommission(15, 'EUR', grid);
      expect(big.commission, 1.05);
      expect(big.gross, 16.05);
      expect(big.minimumApplied, isFalse);
    });

    test('arrondit le net à l\'unité mineure (HALF_UP)', () {
      expect(computeCommission(20.005, 'EUR', grid).net, 20.01);
      expect(computeCommission(20000.5, 'XOF', grid).net, 20001);
    });

    test('devise sans minimum dans la grille : StateError', () {
      expect(() => computeCommission(20, 'GBP', grid), throwsStateError);
    });

    test('devise hors catalogue : StateError', () {
      expect(() => computeCommission(20, 'JPY', grid), throwsStateError);
    });

    test('taux spécial à 0 : commission 0, ni minimum ni bon', () {
      final r = computeCommission(
        20,
        'EUR',
        grid,
        reductions: const CommissionReductions(
          overrideRate: 0,
          voucherFactor: 0.5,
        ),
      );
      expect(r.commission, 0);
      expect(r.gross, 20);
      expect(r.minimumApplied, isFalse);
    });
  });

  group('netForGross', () {
    test('rend le plus grand net dont le brut tient dans le budget', () {
      final net = netForGross(21.40, 'EUR', grid);
      expect(net, 20);
      expect(
        computeCommission(net, 'EUR', grid).gross,
        lessThanOrEqualTo(21.40),
      );
      // Un centime de net en plus dépasserait le budget.
      expect(
        computeCommission(net + 0.01, 'EUR', grid).gross,
        greaterThan(21.40),
      );
    });

    test('budget non positif : BudgetBelowCommissionMinimumException', () {
      expect(
        () => netForGross(0, 'EUR', grid),
        throwsA(isA<BudgetBelowCommissionMinimumException>()),
      );
      expect(
        () => netForGross(-5, 'EUR', grid),
        throwsA(isA<BudgetBelowCommissionMinimumException>()),
      );
    });

    test('toString de l\'exception est lisible', () {
      expect(
        const BudgetBelowCommissionMinimumException().toString(),
        contains('BudgetBelowCommissionMinimum'),
      );
    });
  });
}
