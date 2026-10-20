import 'dart:async';

import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_grid_preload.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/commission_grid_test_doubles.dart';

CommissionGrid _frozenGrid() => CommissionGrid(
  id: 'grid-frozen',
  effectiveFrom: DateTime.utc(2026, 9),
  tiers: const [CommissionTier(fromEur: 0, rate: 0.10)],
  minimums: const {'EUR': 2.00},
);

void main() {
  setUp(CommissionGridStore.reset);
  tearDown(CommissionGridStore.reset);

  test('délai par défaut de 3 s', () {
    expect(kCommissionGridPreloadTimeout, const Duration(seconds: 3));
  });

  group('preloadCommissionGrids', () {
    test('lit une seule fois chaque grille inconnue, ignore les nulles et les '
        'connues', () async {
      useTestCommissionGrid();
      final calls = <String>[];
      await preloadCommissionGrids(
        ['grid-frozen', null, 'grid-frozen', kTestGridId],
        (id) async {
          calls.add(id);
          return _frozenGrid();
        },
      );
      expect(calls, ['grid-frozen']);
      expect(CommissionGridStore.byId('grid-frozen'), isNotNull);
    });

    test('sans lecteur : rien', () async {
      await preloadCommissionGrids(['grid-frozen'], null);
      expect(CommissionGridStore.byId('grid-frozen'), isNull);
    });

    test('tout connu : aucun appel', () async {
      useTestCommissionGrid();
      var called = false;
      await preloadCommissionGrids([kTestGridId], (id) async {
        called = true;
        return null;
      });
      expect(called, isFalse);
    });

    test('échec de lecture : ne lève pas', () async {
      await preloadCommissionGrids(['grid-frozen'], (id) async {
        throw Exception('réseau');
      });
      expect(CommissionGridStore.byId('grid-frozen'), isNull);
    });

    test('lecture trop lente : rend la main, la grille arrive ensuite en '
        'cache', () async {
      final completer = Completer<CommissionGrid?>();
      await preloadCommissionGrids(
        ['grid-frozen'],
        (id) => completer.future,
        timeout: const Duration(milliseconds: 10),
      );
      expect(CommissionGridStore.byId('grid-frozen'), isNull);
      completer.complete(_frozenGrid());
      await Future<void>.delayed(Duration.zero);
      expect(CommissionGridStore.byId('grid-frozen'), isNotNull);
    });
  });
}
