import 'dart:convert';
import 'dart:io';

import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les vecteurs sont ceux du back (`src/test/resources/commission/vectors.json`),
/// recopiés tels quels : le portage Dart doit rendre exactement les mêmes montants.
void main() {
  final fixture =
      jsonDecode(
            File('test/fixtures/commission/vectors.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final grid = CommissionGrid.fromJson({
    ...(fixture['grid'] as Map<String, dynamic>),
    'gridId': 'vectors',
    'effectiveFrom': DateTime.utc(2026).toIso8601String(),
  });
  final vectors = (fixture['vectors'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  double num_(Object? v) => double.parse(v as String);

  CommissionReductions reductionsOf(
    Map<String, dynamic> r,
  ) => CommissionReductions(
    overrideRate: r['overrideRate'] == null ? null : num_(r['overrideRate']),
    voucherFactor: r['voucherFactor'] == null ? null : num_(r['voucherFactor']),
  );

  var executed = 0;
  var skipped = 0;

  group('vecteurs du back', () {
    for (final v in vectors) {
      final reductions = (v['reductions'] as Map<String, dynamic>?) ?? const {};
      final expected = v['expected'] as Map<String, dynamic>;
      final currency = v['currency'] as String;

      if (reductions.containsKey('promoPoints') ||
          reductions.containsKey('promoPricePercent')) {
        // Le code promo n'est jamais calculé dans l'app : seul le serveur le chiffre.
        skipped++;
        continue;
      }
      executed++;
      final red = reductionsOf(reductions);

      test(v['case'] as String, () {
        if (expected['error'] == 'budget-below-commission-minimum') {
          expect(
            () =>
                netForGross(num_(v['gross']), currency, grid, reductions: red),
            throwsA(isA<BudgetBelowCommissionMinimumException>()),
          );
        } else if (v.containsKey('net')) {
          final r = computeCommission(
            num_(v['net']),
            currency,
            grid,
            reductions: red,
          );
          expect(r.commission, num_(expected['commission']));
          expect(r.gross, num_(expected['gross']));
          expect(r.net, num_(v['net']));
          expect(r.minimumApplied, expected['minimumApplied']);
        } else {
          final net = netForGross(
            num_(v['gross']),
            currency,
            grid,
            reductions: red,
          );
          expect(net, num_(expected['net']));
          expect(
            computeCommission(net, currency, grid, reductions: red).commission,
            num_(expected['commission']),
          );
        }
      });
    }
  });

  test('exécute 23 vecteurs et en ignore 5 (promo)', () {
    expect(vectors, hasLength(28));
    expect(executed, 23);
    expect(skipped, 5);
  });
}
