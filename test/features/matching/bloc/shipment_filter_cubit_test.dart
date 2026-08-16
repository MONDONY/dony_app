import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAnalytics extends Mock implements AnalyticsService {}

BidModel _bid({
  String status = 'ACCEPTED',
  String? depart = 'Paris',
  String? arrivee = 'Dakar',
  String? recipient,
  String? traveler,
  String? tracking,
  DateTime? departureDate,
  DateTime? createdAt,
}) => BidModel(
  id: 'b-${status}_${depart}_$arrivee',
  announcementId: 'a1',
  senderId: 's1',
  status: status,
  departureCity: depart,
  arrivalCity: arrivee,
  recipientName: recipient,
  travelerName: traveler,
  trackingNumber: tracking,
  departureDate: departureDate,
  createdAt: createdAt ?? DateTime(2026, 5),
  updatedAt: createdAt ?? DateTime(2026, 5),
);

void main() {
  final now = DateTime(2026, 6, 3, 12);

  group('shipmentMatchesQuery', () {
    test('vide -> tout passe', () {
      expect(shipmentMatchesQuery(_bid(), ''), isTrue);
    });
    test('match ville (accents/casse)', () {
      expect(shipmentMatchesQuery(_bid(arrivee: 'Dákar'), 'dakar'), isTrue);
    });
    test('match destinataire', () {
      expect(
        shipmentMatchesQuery(_bid(recipient: 'Awa Ndiaye'), 'ndiaye'),
        isTrue,
      );
    });
    test('match voyageur', () {
      expect(shipmentMatchesQuery(_bid(traveler: 'Modou'), 'modou'), isTrue);
    });
    test('match n° suivi', () {
      expect(shipmentMatchesQuery(_bid(tracking: 'TRK-99'), 'trk-99'), isTrue);
    });
    test('aucune correspondance -> false', () {
      expect(shipmentMatchesQuery(_bid(), 'zzz'), isFalse);
    });
  });

  group('shipmentDateFor', () {
    test('departure utilise departureDate', () {
      final b = _bid(
        departureDate: DateTime(2026, 5, 10),
        createdAt: DateTime(2026, 4),
      );
      expect(
        shipmentDateFor(b, ShipmentPeriodBasis.departure),
        DateTime(2026, 5, 10),
      );
    });
    test('departure fallback createdAt si null', () {
      final b = _bid(createdAt: DateTime(2026, 4));
      expect(
        shipmentDateFor(b, ShipmentPeriodBasis.departure),
        DateTime(2026, 4),
      );
    });
    test('creation utilise createdAt', () {
      final b = _bid(
        departureDate: DateTime(2026, 5, 10),
        createdAt: DateTime(2026, 4),
      );
      expect(
        shipmentDateFor(b, ShipmentPeriodBasis.creation),
        DateTime(2026, 4),
      );
    });
  });

  group('rangeForPreset', () {
    test('all -> null', () {
      expect(rangeForPreset(ShipmentPeriodPreset.all, null, now), isNull);
    });
    test('thisWeek -> lundi minuit', () {
      // 3 juin 2026 est un mercredi -> lundi = 1er juin, borné à minuit.
      final r = rangeForPreset(ShipmentPeriodPreset.thisWeek, null, now)!;
      expect(r.start, DateTime(2026, 6));
      expect(r.end, now);
    });
    test('thisMonth -> 1er du mois -> now', () {
      final r = rangeForPreset(ShipmentPeriodPreset.thisMonth, null, now)!;
      expect(r.start, DateTime(2026, 6));
      expect(r.end, now);
    });
    test('last3Months -> J-90 borné au début de journée', () {
      // 2026-06-03 12:00 - 90j = 2026-03-05 ; dateOnly -> minuit.
      final r = rangeForPreset(ShipmentPeriodPreset.last3Months, null, now)!;
      expect(r.start, DateTime(2026, 3, 5));
    });
    test('thisYear -> 1er janvier', () {
      final r = rangeForPreset(ShipmentPeriodPreset.thisYear, null, now)!;
      expect(r.start, DateTime(2026));
    });
    test('custom -> bornes étendues (fin 23:59:59)', () {
      final custom = DateTimeRange(
        start: DateTime(2026, 5),
        end: DateTime(2026, 5, 31),
      );
      final r = rangeForPreset(ShipmentPeriodPreset.custom, custom, now)!;
      expect(r.start, DateTime(2026, 5));
      expect(r.end, DateTime(2026, 5, 31, 23, 59, 59));
    });
    test('custom sans range -> null', () {
      expect(rangeForPreset(ShipmentPeriodPreset.custom, null, now), isNull);
    });
  });

  group('applyShipmentFilters', () {
    final bids = [
      _bid(departureDate: DateTime(2026, 6, 2)),
      _bid(
        status: 'COMPLETED',
        arrivee: 'Abidjan',
        departureDate: DateTime(2026, 5, 2),
      ),
      _bid(
        status: 'PENDING',
        arrivee: 'Bamako',
        departureDate: DateTime(2026, 6),
      ),
    ];
    test('statuts vides -> tout', () {
      expect(
        applyShipmentFilters(bids, const ShipmentFilterState(), now).length,
        3,
      );
    });
    test('filtre statut', () {
      final r = applyShipmentFilters(
        bids,
        const ShipmentFilterState(statuses: {'COMPLETED'}),
        now,
      );
      expect(r.single.status, 'COMPLETED');
    });
    test('filtre recherche', () {
      final r = applyShipmentFilters(
        bids,
        const ShipmentFilterState(query: 'bamako'),
        now,
      );
      expect(r.single.arrivalCity, 'Bamako');
    });
    test('filtre période (ce mois, basé départ) exclut le 2 mai', () {
      final r = applyShipmentFilters(
        bids,
        const ShipmentFilterState(periodPreset: ShipmentPeriodPreset.thisMonth),
        now,
      );
      expect(r.every((b) => b.arrivalCity != 'Abidjan'), isTrue);
      expect(r.length, 2);
    });
    test('combinaison statut + période (ET)', () {
      final r = applyShipmentFilters(
        bids,
        const ShipmentFilterState(
          statuses: {'ACCEPTED'},
          periodPreset: ShipmentPeriodPreset.thisMonth,
        ),
        now,
      );
      expect(r.single.status, 'ACCEPTED');
    });
    test('tri : statut le plus avancé en tête', () {
      final r = applyShipmentFilters(bids, const ShipmentFilterState(), now);
      expect(r.first.status, 'ACCEPTED');
    });
    test('ARRIVED passe devant IN_TRANSIT et COMPLETED dans le tri', () {
      final r = applyShipmentFilters([
        _bid(status: 'COMPLETED'),
        _bid(status: 'IN_TRANSIT'),
        _bid(status: 'ARRIVED'),
      ], const ShipmentFilterState(), now);
      expect(r.map((b) => b.status), ['ARRIVED', 'IN_TRANSIT', 'COMPLETED']);
    });
    test('kEnvoisEnCours retient les colis ARRIVED', () {
      expect(kEnvoisEnCours, contains('ARRIVED'));
      final r = applyShipmentFilters([
        _bid(status: 'ARRIVED'),
      ], const ShipmentFilterState(statuses: kEnvoisEnCours), now);
      expect(r, hasLength(1));
    });
  });

  group('ShipmentFilterCubit', () {
    late _MockAnalytics analytics;
    setUp(() {
      analytics = _MockAnalytics();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
    });

    blocTest<ShipmentFilterCubit, ShipmentFilterState>(
      'setQuery met à jour query SANS analytics',
      build: () => ShipmentFilterCubit(analytics),
      act: (c) => c.setQuery('dakar'),
      expect: () => [const ShipmentFilterState(query: 'dakar')],
      verify: (_) => verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ),
    );

    blocTest<ShipmentFilterCubit, ShipmentFilterState>(
      'applyQuickPreset émet l\'event sans le texte',
      build: () => ShipmentFilterCubit(analytics),
      act: (c) => c.applyQuickPreset(kEnvoisEnCours),
      expect: () => [const ShipmentFilterState(statuses: kEnvoisEnCours)],
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.shipmentFilterApplied,
          properties: any(
            named: 'properties',
            that: isA<Map>().having(
              (m) => m.containsKey('query'),
              'no query',
              isFalse,
            ),
          ),
        ),
      ).called(1),
    );

    blocTest<ShipmentFilterCubit, ShipmentFilterState>(
      'reset revient à l\'état initial',
      build: () => ShipmentFilterCubit(analytics),
      seed: () => const ShipmentFilterState(query: 'x', statuses: {'ACCEPTED'}),
      act: (c) => c.reset(),
      expect: () => [const ShipmentFilterState()],
    );

    blocTest<ShipmentFilterCubit, ShipmentFilterState>(
      'setStatuses émet le nouvel ensemble ET déclenche analytics',
      build: () => ShipmentFilterCubit(analytics),
      act: (c) => c.setStatuses({'COMPLETED', 'CANCELLED'}),
      expect: () => [
        const ShipmentFilterState(statuses: {'COMPLETED', 'CANCELLED'}),
      ],
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.shipmentFilterApplied,
          properties: any(named: 'properties'),
        ),
      ).called(1),
    );

    blocTest<ShipmentFilterCubit, ShipmentFilterState>(
      'setPeriod avec preset non-custom annule customRange',
      build: () => ShipmentFilterCubit(analytics),
      seed: () => ShipmentFilterState(
        periodPreset: ShipmentPeriodPreset.custom,
        customRange: DateTimeRange(
          start: DateTime(2026, 5),
          end: DateTime(2026, 5, 31),
        ),
      ),
      act: (c) => c.setPeriod(
        basis: ShipmentPeriodBasis.departure,
        preset: ShipmentPeriodPreset.thisMonth,
      ),
      expect: () => [
        const ShipmentFilterState(
          periodPreset: ShipmentPeriodPreset.thisMonth,
          // customRange doit être null
        ),
      ],
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.shipmentFilterApplied,
          properties: any(named: 'properties'),
        ),
      ).called(1),
    );

    blocTest<ShipmentFilterCubit, ShipmentFilterState>(
      'setPeriod avec preset custom conserve la plage',
      build: () => ShipmentFilterCubit(analytics),
      act: (c) {
        final range = DateTimeRange(
          start: DateTime(2026, 4),
          end: DateTime(2026, 4, 30),
        );
        c.setPeriod(
          basis: ShipmentPeriodBasis.creation,
          preset: ShipmentPeriodPreset.custom,
          range: range,
        );
      },
      expect: () => [
        isA<ShipmentFilterState>()
            .having(
              (s) => s.periodPreset,
              'preset',
              ShipmentPeriodPreset.custom,
            )
            .having((s) => s.periodBasis, 'basis', ShipmentPeriodBasis.creation)
            .having((s) => s.customRange, 'customRange', isNotNull),
      ],
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.shipmentFilterApplied,
          properties: any(named: 'properties'),
        ),
      ).called(1),
    );

    blocTest<ShipmentFilterCubit, ShipmentFilterState>(
      'setPeriod avec basis = creation déclenche analytics avec bon period_basis',
      build: () => ShipmentFilterCubit(analytics),
      act: (c) => c.setPeriod(
        basis: ShipmentPeriodBasis.creation,
        preset: ShipmentPeriodPreset.thisYear,
      ),
      expect: () => [
        const ShipmentFilterState(
          periodBasis: ShipmentPeriodBasis.creation,
          periodPreset: ShipmentPeriodPreset.thisYear,
        ),
      ],
      verify: (_) => verify(
        () => analytics.logEvent(
          AnalyticsEvents.shipmentFilterApplied,
          properties: any(
            named: 'properties',
            that: isA<Map>().having(
              (m) => m['period_basis'],
              'period_basis',
              'creation',
            ),
          ),
        ),
      ).called(1),
    );
  });

  group('applyShipmentFilters avec periodBasis = creation', () {
    final bids = [
      _bid(departureDate: DateTime(2026, 6, 2), createdAt: DateTime(2026, 6)),
      _bid(
        status: 'COMPLETED',
        arrivee: 'Abidjan',
        departureDate: DateTime(2026, 6, 2),
        createdAt: DateTime(2026, 4), // créé en avril
      ),
    ];

    final now = DateTime(2026, 6, 3, 12);

    test('filtre par date de création (ce mois) exclut créé en avril', () {
      const filter = ShipmentFilterState(
        periodBasis: ShipmentPeriodBasis.creation,
        periodPreset: ShipmentPeriodPreset.thisMonth,
      );
      final r = applyShipmentFilters(bids, filter, now);
      expect(r.every((b) => b.arrivalCity != 'Abidjan'), isTrue);
      expect(r.length, 1);
    });

    test('filtre par date de création (last3Months) inclut les deux', () {
      const filter = ShipmentFilterState(
        periodBasis: ShipmentPeriodBasis.creation,
        periodPreset: ShipmentPeriodPreset.last3Months,
      );
      final r = applyShipmentFilters(bids, filter, now);
      expect(r.length, 2);
    });
  });
}
