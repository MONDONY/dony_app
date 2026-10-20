import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:dony/core/pricing/commission_rate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CommissionGrid grid(String id, DateTime from) => CommissionGrid(
    id: id,
    effectiveFrom: from,
    tiers: const [CommissionTier(fromEur: 0, rate: 0.07)],
    minimums: const {'EUR': 1.0},
  );

  final g1 = grid('g1', DateTime.utc(2026, 10));
  final g2 = grid('g2', DateTime.utc(2026, 11, 20, 9));

  setUp(CommissionGridStore.reset);
  tearDown(CommissionGridStore.reset);

  group('activeAt', () {
    test('renvoie current avant la date de next', () {
      CommissionGridStore.setConfig(
        CommissionGridConfig(current: g1, next: g2),
      );
      expect(
        CommissionGridStore.activeAt(DateTime.utc(2026, 11, 20, 8, 59)),
        same(g1),
      );
    });

    test('bascule sur next dès sa date franchie', () {
      CommissionGridStore.setConfig(
        CommissionGridConfig(current: g1, next: g2),
      );
      expect(
        CommissionGridStore.activeAt(DateTime.utc(2026, 11, 20, 9)),
        same(g2),
      );
    });

    test('sans current renvoie next une fois franchie, null avant', () {
      CommissionGridStore.setConfig(CommissionGridConfig(next: g2));
      expect(
        CommissionGridStore.activeAt(DateTime.utc(2026, 11, 20, 8, 59)),
        isNull,
      );
      expect(
        CommissionGridStore.activeAt(DateTime.utc(2026, 11, 20, 9)),
        same(g2),
      );
    });

    test('sans aucune grille renvoie null', () {
      expect(CommissionGridStore.activeAt(DateTime.utc(2030)), isNull);
      expect(activeCommissionGrid, isNull);
    });

    test('compare en UTC une date locale', () {
      CommissionGridStore.setConfig(
        CommissionGridConfig(current: g1, next: g2),
      );
      final local = DateTime.utc(2026, 11, 20, 9).toLocal();
      expect(CommissionGridStore.activeAt(local), same(g2));
    });

    test('activeCommissionGrid lit l\'heure courante', () {
      final past = grid('past', DateTime.utc(2020));
      final future = grid('future', DateTime.utc(2999));
      CommissionGridStore.setConfig(
        CommissionGridConfig(current: past, next: future),
      );
      expect(activeCommissionGrid, same(past));
    });
  });

  group('byId', () {
    test('trouve current, next et les grilles ajoutées par put', () {
      CommissionGridStore.setConfig(
        CommissionGridConfig(current: g1, next: g2),
      );
      final g3 = grid('g3', DateTime.utc(2026));
      CommissionGridStore.put(g3);
      expect(CommissionGridStore.byId('g1'), same(g1));
      expect(CommissionGridStore.byId('g2'), same(g2));
      expect(CommissionGridStore.byId('g3'), same(g3));
      expect(CommissionGridStore.byId('inconnue'), isNull);
      expect(CommissionGridStore.byId(null), isNull);
    });
  });

  group('ensure', () {
    test('n\'appelle pas fetch pour une grille déjà connue', () async {
      CommissionGridStore.setConfig(CommissionGridConfig(current: g1));
      var calls = 0;
      final result = await CommissionGridStore.ensure('g1', (_) async {
        calls++;
        return g2;
      });
      expect(result, same(g1));
      expect(calls, 0);
    });

    test('met en cache le résultat de fetch', () async {
      var calls = 0;
      Future<CommissionGrid?> fetch(String id) async {
        calls++;
        return grid(id, DateTime.utc(2026));
      }

      final first = await CommissionGridStore.ensure('g9', fetch);
      final second = await CommissionGridStore.ensure('g9', fetch);
      expect(first?.id, 'g9');
      expect(second, same(first));
      expect(calls, 1);
      expect(CommissionGridStore.byId('g9'), same(first));
    });

    test('renvoie null et n\'échoue pas si fetch lève', () async {
      final result = await CommissionGridStore.ensure('g9', (_) async {
        throw StateError('réseau');
      });
      expect(result, isNull);
      expect(CommissionGridStore.byId('g9'), isNull);
    });

    test(
      'un échec synchrone de fetch n\'est pas gardé : nouvel essai',
      () async {
        expect(
          await CommissionGridStore.ensure('g9', (_) => throw StateError('x')),
          isNull,
        );
        final retried = await CommissionGridStore.ensure(
          'g9',
          (id) async => grid(id, DateTime.utc(2026)),
        );
        expect(retried?.id, 'g9');
      },
    );

    test('renvoie null quand fetch ne trouve rien (404)', () async {
      expect(await CommissionGridStore.ensure('g9', (_) async => null), isNull);
      expect(CommissionGridStore.byId('g9'), isNull);
    });

    test('ensure(null) renvoie null sans appel', () async {
      var calls = 0;
      final result = await CommissionGridStore.ensure(null, (_) async {
        calls++;
        return g1;
      });
      expect(result, isNull);
      expect(calls, 0);
    });

    test('des appels simultanés partagent une seule lecture', () async {
      var calls = 0;
      Future<CommissionGrid?> fetch(String id) async {
        calls++;
        return grid(id, DateTime.utc(2026));
      }

      final results = await Future.wait([
        CommissionGridStore.ensure('g9', fetch),
        CommissionGridStore.ensure('g9', fetch),
      ]);
      expect(calls, 1);
      expect(results[0], same(results[1]));
    });
  });

  group('CommissionGridConfig.fromJson', () {
    Map<String, dynamic> gridJson(String id) => {
      'gridId': id,
      'effectiveFrom': '2026-10-01T00:00:00',
      'tiers': [
        {'fromEur': 0, 'rate': 0.07},
      ],
      'minimums': {'EUR': 1},
    };

    test('lit current et next, tolère null', () {
      final both = CommissionGridConfig.fromJson({
        'current': gridJson('a'),
        'next': gridJson('b'),
      });
      expect(both.current?.id, 'a');
      expect(both.next?.id, 'b');
      final empty = CommissionGridConfig.fromJson({'current': null});
      expect(empty.current, isNull);
      expect(empty.next, isNull);
    });

    test('lit legacyRate quand il est présent et valide', () {
      final config = CommissionGridConfig.fromJson({
        'current': gridJson('a'),
        'next': null,
        'legacyRate': 0.05,
      });
      expect(config.legacyRate, 0.05);
      expect(
        CommissionGridConfig.fromJson({
          'current': null,
          'legacyRate': 0,
        }).legacyRate,
        0.0,
      );
    });

    test('legacyRate absent (back sans le champ) : null', () {
      final config = CommissionGridConfig.fromJson({
        'current': gridJson('a'),
        'next': null,
      });
      expect(config.legacyRate, isNull);
      expect(config.current?.id, 'a');
    });

    test('legacyRate invalide : ignoré sans casser la grille', () {
      for (final raw in <Object?>[1, 1.5, -0.01, '0.05', true]) {
        final config = CommissionGridConfig.fromJson({
          'current': gridJson('a'),
          'legacyRate': raw,
        });
        expect(config.legacyRate, isNull, reason: '$raw');
        expect(config.current?.id, 'a');
      }
    });

    test('un JSON malformé lève une erreur que l\'appelant attrape', () {
      expect(
        () => CommissionGridConfig.fromJson({
          'current': {'gridId': 1},
        }),
        throwsA(anyOf(isA<TypeError>(), isA<FormatException>())),
      );
    });
  });

  group('applyCommissionGridConfig', () {
    final grid = CommissionGrid(
      id: 'g',
      effectiveFrom: DateTime.utc(2026, 10),
      tiers: const [CommissionTier(fromEur: 0, rate: 0.07)],
      minimums: const {'EUR': 1.0},
    );

    setUp(resetDonyCommissionRate);
    tearDown(resetDonyCommissionRate);

    test('pose la grille et legacyRate comme taux des objets sans grille', () {
      setDonyCommissionRate(0.07); // 1re tranche servie par commission-rate
      applyCommissionGridConfig(
        CommissionGridConfig(current: grid, legacyRate: 0.05),
      );
      expect(CommissionGridStore.byId('g'), same(grid));
      expect(donyCommissionRate, 0.05);
    });

    test('legacyRate prime sur commission-rate arrivé après', () {
      applyCommissionGridConfig(
        CommissionGridConfig(current: grid, legacyRate: 0.05),
      );
      setDonyCommissionRate(0.07);
      expect(donyCommissionRate, 0.05);
    });

    test('sans legacyRate, le taux de commission-rate reste', () {
      setDonyCommissionRate(0.12);
      applyCommissionGridConfig(CommissionGridConfig(current: grid));
      expect(donyCommissionRate, 0.12);
      // Et commission-rate arrivé après s'applique toujours.
      setDonyCommissionRate(0.08);
      expect(donyCommissionRate, 0.08);
    });

    test('un legacyRate hors [0,1[ ne remplace rien', () {
      setDonyCommissionRate(0.12);
      setLegacyCommissionRate(1);
      setLegacyCommissionRate(-0.1);
      setLegacyCommissionRate(double.nan);
      setLegacyCommissionRate(null);
      expect(donyCommissionRate, 0.12);
      setDonyCommissionRate(0.08);
      expect(donyCommissionRate, 0.08);
    });

    test('legacyRate à 0 est accepté', () {
      setLegacyCommissionRate(0);
      expect(donyCommissionRate, 0);
    });
  });
}
