import 'dart:async';

import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/thread_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/commission_grid_test_doubles.dart';

NegotiationThread _thread({String? gridId, String currency = 'EUR'}) =>
    NegotiationThread(
      id: 't-1',
      packageRequestId: 'pr-1',
      travelerId: 'tr-1',
      travelerTravelDate: DateTime.utc(2026, 11, 2),
      travelerAvailableKg: 10,
      status: NegotiationThreadStatus.open,
      currentPriceEur: 20,
      roundsCount: 1,
      lastActivityAt: DateTime.utc(2026, 10, 19),
      createdAt: DateTime.utc(2026, 10, 19),
      messages: const [],
      currency: currency,
      commissionGridId: gridId,
    );

/// Grille figée à 10 %, minimum 2 € : distincte de la grille de test (7 %).
CommissionGrid _frozenGrid() => CommissionGrid(
  id: 'grid-frozen',
  effectiveFrom: DateTime.utc(2026, 9),
  tiers: const [CommissionTier(fromEur: 0, rate: 0.10)],
  minimums: const {'EUR': 2.00},
);

void main() {
  setUp(CommissionGridStore.reset);
  tearDown(() {
    CommissionGridStore.reset();
    setDonyCommissionRate(kDonyCommissionRateDefault);
  });

  group('ThreadPricer.priceFor', () {
    test('fil sans commissionGridId sous grille : taux unique (Ruling A8, '
        '20 € → 21,00 € à 5 %)', () {
      useTestCommissionGrid();
      setDonyCommissionRate(0.05);
      final p = ThreadPricer.of(_thread()).priceFor(20);
      expect(p.gross, closeTo(21.00, 1e-9));
      expect(p.commission, closeTo(1.00, 1e-9));
      expect(p.fromGrid, isFalse);
      expect(p.minimumApplied, isFalse);
    });

    test('grille figée connue (grille en vigueur) : 20 € → 21,40 €', () {
      useTestCommissionGrid();
      final p = ThreadPricer.of(_thread(gridId: kTestGridId)).priceFor(20);
      expect(p.gross, closeTo(21.40, 1e-9));
      expect(p.fromGrid, isTrue);
    });

    test('id connu du store : grille figée utilisée même si une autre est '
        'active', () {
      useTestCommissionGrid();
      CommissionGridStore.put(_frozenGrid());
      final p = ThreadPricer.of(_thread(gridId: 'grid-frozen')).priceFor(30);
      // 30 € × 10 % = 3,00 € (la grille active aurait donné 2,10 €).
      expect(p.commission, closeTo(3.00, 1e-9));
      expect(p.gross, closeTo(33.00, 1e-9));
    });

    test('id inconnu : repli sur la grille active', () {
      useTestCommissionGrid();
      final p = ThreadPricer.of(_thread(gridId: 'grid-inconnue')).priceFor(20);
      expect(p.gross, closeTo(21.40, 1e-9));
    });

    test('id inconnu sans grille publiée : taux unique', () {
      setDonyCommissionRate(0.12);
      final p = ThreadPricer.of(_thread(gridId: 'grid-inconnue')).priceFor(35);
      expect(p.gross, closeTo(39.20, 1e-9));
      expect(p.fromGrid, isFalse);
    });

    test('minimum de la grille : net 5 € → frais 1,00 € (minimum)', () {
      useTestCommissionGrid();
      final p = ThreadPricer.of(_thread(gridId: kTestGridId)).priceFor(5);
      expect(p.commission, closeTo(1.00, 1e-9));
      expect(p.gross, closeTo(6.00, 1e-9));
      expect(p.minimumApplied, isTrue);
    });

    test('grille arrivée en cache après la construction : prise au prochain '
        'calcul', () {
      useTestCommissionGrid();
      final pricer = ThreadPricer.of(_thread(gridId: 'grid-frozen'));
      expect(pricer.priceFor(30).commission, closeTo(2.10, 1e-9));
      CommissionGridStore.put(_frozenGrid());
      expect(pricer.priceFor(30).commission, closeTo(3.00, 1e-9));
    });

    test('taux unique : commission arrondie au centime comme le back '
        '(FLUTTER-Q4)', () {
      const pricer = ThreadPricer();
      setDonyCommissionRate(0.0499);
      // 70 × 4,99 % = 3,493 → 3,49 ; brut 73,49, comme PriceBreakdown.fromNet.
      expect(pricer.priceFor(70).commission, closeTo(3.49, 1e-9));
      expect(pricer.priceFor(70).gross, closeTo(73.49, 1e-9));
      // 69,99 × 5 % = 3,4995 → 3,50 : arrondi demi vers le haut.
      setDonyCommissionRate(0.05);
      expect(pricer.priceFor(69.99).gross, closeTo(73.49, 1e-9));
    });

    test('devise du fil : XOF à l\'unité, minimum 650 F CFA', () {
      useTestCommissionGrid();
      final p = ThreadPricer.of(
        _thread(gridId: kTestGridId, currency: 'XOF'),
      ).priceFor(5000);
      expect(p.commission, 650);
      expect(p.gross, 5650);
      expect(p.minimumApplied, isTrue);
    });
  });

  group('ThreadPricer.resolve', () {
    test('sans brut servi : calcul local', () {
      useTestCommissionGrid();
      final p = ThreadPricer.of(_thread(gridId: kTestGridId)).resolve(5);
      expect(p.gross, closeTo(6.00, 1e-9));
      expect(p.minimumApplied, isTrue);
    });

    test('brut servi : il prime, frais = brut − net', () {
      useTestCommissionGrid();
      final p = ThreadPricer.of(
        _thread(gridId: kTestGridId),
      ).resolve(20, servedGross: 21.00);
      expect(p.gross, 21.00);
      expect(p.commission, closeTo(1.00, 1e-9));
      expect(p.net, 20);
    });

    test('brut servi égal au calcul local : la mention minimum est gardée', () {
      useTestCommissionGrid();
      final p = ThreadPricer.of(
        _thread(gridId: kTestGridId),
      ).resolve(5, servedGross: 6.00);
      expect(p.minimumApplied, isTrue);
    });

    test(
      'brut servi différent (réduction scellée) : pas de mention minimum',
      () {
        useTestCommissionGrid();
        final p = ThreadPricer.of(
          _thread(gridId: kTestGridId),
        ).resolve(5, servedGross: 5.50);
        expect(p.minimumApplied, isFalse);
        expect(p.commission, closeTo(0.50, 1e-9));
      },
    );
  });

  test('égalité par grille et devise', () {
    expect(
      ThreadPricer.of(_thread(gridId: 'g')),
      ThreadPricer.of(_thread(gridId: 'g')),
    );
    expect(
      ThreadPricer.of(_thread(gridId: 'g')).hashCode,
      ThreadPricer.of(_thread(gridId: 'g')).hashCode,
    );
    expect(ThreadPricer.of(_thread()), const ThreadPricer());
    expect(
      ThreadPricer.of(_thread(gridId: 'g')),
      isNot(ThreadPricer.of(_thread(gridId: 'g', currency: 'XOF'))),
    );
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
