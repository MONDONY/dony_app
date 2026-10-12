import 'package:dony/features/flights/data/models/flight_filters.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_recent_search.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../bloc/flights_test_doubles.dart';

const _paris = FlightPlace(code: 'PAR', name: 'Paris', countryCode: 'FR');
const _abidjan = FlightPlace(code: 'ABJ', name: 'Abidjan');

void main() {
  group('FlightOffer, contrat récent du back', () {
    test('arrivées et durées par trajet, heures locales des aéroports', () {
      final o = FlightOffer.fromJson(const {
        'originCode': 'PAR',
        'destinationCode': 'ABJ',
        'departureAt': '2026-12-12T23:30:00+01:00',
        'arrivalAt': '2026-12-13T06:50:00Z',
        'returnAt': '2027-01-03T23:30:00Z',
        'returnArrivalAt': '2027-01-05T06:50:00+01:00',
        'price': 498,
        'durationMinutes': 760,
        'outboundDurationMinutes': 380,
        'returnDurationMinutes': '380',
        'transfers': '0',
        'returnTransfers': 1,
        'flightNumber': '950',
        'gate': '  ',
        'offerPath': '/search/B',
      });

      // Heure locale de chaque aéroport, sans conversion au fuseau du
      // téléphone.
      expect(o.arrivalAt, DateTime(2026, 12, 13, 6, 50));
      expect(o.returnArrivalAt, DateTime(2027, 1, 5, 6, 50));
      expect(o.arrivalDayOffset, 1);
      expect(o.returnArrivalDayOffset, 2);
      expect(o.outboundMinutes, 380);
      expect(o.returnDurationMinutes, 380);
      expect(o.transfers, 0);
      expect(o.isDirect, isTrue);
      expect(o.returnTransfers, 1);
      // Un site vendeur vide est ignoré.
      expect(o.gate, isNull);
    });

    test(
      'ancien back : pas d\'arrivée, durée totale masquée en aller-retour',
      () {
        final o = FlightOffer.fromJson(const {
          'originCode': 'PAR',
          'destinationCode': 'ABJ',
          'departureAt': '2026-12-12T11:30:00+01:00',
          'returnAt': '2027-01-08T14:05:00+00:00',
          'durationMinutes': 1200,
          'transfers': 'x',
          'offerPath': '/search/A',
        });

        expect(o.arrivalAt, isNull);
        expect(o.arrivalDayOffset, 0);
        expect(o.outboundMinutes, isNull);
        expect(o.transfers, isNull);
      },
    );

    test(
      'ancien back en aller simple : la durée totale est celle de l\'aller',
      () {
        final o = FlightOffer.fromJson(const {
          'departureAt': '2026-12-12T11:30:00+01:00',
          'durationMinutes': 585,
          'offerPath': '/search/A',
        });
        expect(o.outboundMinutes, 585);
      },
    );

    test('décalage de jour jamais négatif', () {
      expect(
        FlightOffer.dayOffset(DateTime(2026, 12, 12), DateTime(2026, 12, 11)),
        0,
      );
      expect(FlightOffer.dayOffset(null, DateTime(2026)), 0);
    });
  });

  group('FlightSearchResult.searchPath', () {
    test('chemin de recherche gardé', () {
      final r = FlightSearchResult.fromJson(const {
        'searchPath': '/search/PAR1212ABJ1',
        'offers': <Object>[],
      });
      expect(r.searchPath, '/search/PAR1212ABJ1');
    });

    test('absent ou suspect : ignoré', () {
      expect(FlightSearchResult.fromJson(const {}).searchPath, isNull);
      expect(
        FlightSearchResult.fromJson(const {
          'searchPath': 'https://x.test',
        }).searchPath,
        isNull,
      );
    });
  });

  group('FlightSearchQuery.roundTrip', () {
    test('déduit de la date de retour, sinon explicite', () {
      expect(
        FlightSearchQuery(returnDate: FlightWhen.day(DateTime(2027))).roundTrip,
        isTrue,
      );
      const q = FlightSearchQuery(roundTrip: true);
      expect(q.needsReturnDate, isTrue);
      expect(q.isRoundTrip, isFalse);
      expect(q.swapped().roundTrip, isTrue);
      expect(q.copyWith(roundTrip: false).needsReturnDate, isFalse);
    });
  });

  group('FlightRecentSearch', () {
    final recent = FlightRecentSearch(
      origin: _paris,
      destination: _abidjan,
      departure: FlightWhen.day(DateTime(2026, 12, 12)),
      returnDate: FlightWhen.month(DateTime(2027)),
      roundTrip: true,
      directOnly: true,
      lowestPrice: 389,
      currency: 'EUR',
      searchedAt: DateTime(2026, 10, 10, 9),
    );

    test('aller-retour JSON sans perte', () {
      expect(FlightRecentSearch.tryParse(recent.toJson()), recent);
      expect(recent.toQuery().returnDate, FlightWhen.month(DateTime(2027)));
      expect(recent.toQuery().directOnly, isTrue);
    });

    test('même trajet et mêmes dates : même clé', () {
      final again = FlightRecentSearch.fromQuery(
        recent.toQuery(),
        lowestPrice: 400,
        at: DateTime(2026, 10, 11),
      );
      expect(again.dedupKey, recent.dedupKey);
    });

    test('entrée illisible : ignorée', () {
      expect(FlightRecentSearch.tryParse('x'), isNull);
      expect(FlightRecentSearch.tryParse({'origin': 'PAR'}), isNull);
      expect(
        FlightRecentSearch.tryParse({
          'origin': {'code': 'PAR'},
          'destination': {'code': ''},
          'searchedAt': '2026-10-10',
        }),
        isNull,
      );
      final noDates = FlightRecentSearch.tryParse({
        'origin': {'code': 'PAR', 'name': 'Paris'},
        'destination': {'code': 'ABJ', 'name': 'Abidjan'},
        'departure': {'date': 'pas une date'},
        'searchedAt': '2026-10-10T09:00:00',
      });
      expect(noDates?.departure, isNull);
      expect(noDates?.roundTrip, isFalse);
    });
  });

  group('FlightFilters, horaires et compteur', () {
    test('tranches horaires de départ', () {
      expect(
        FlightDaySlot.of(DateTime(2026, 1, 1, 6, 10)),
        FlightDaySlot.morning,
      );
      expect(
        FlightDaySlot.of(DateTime(2026, 1, 1, 12)),
        FlightDaySlot.afternoon,
      );
      expect(
        FlightDaySlot.of(DateTime(2026, 1, 1, 23, 30)),
        FlightDaySlot.evening,
      );
      expect(FlightDaySlot.of(DateTime(2026, 1, 1, 3)), FlightDaySlot.night);
      // Minuit pile : heure inconnue.
      expect(FlightDaySlot.of(DateTime(2026)), isNull);
      expect(FlightDaySlot.of(null), isNull);
    });

    test('filtre horaire et nombre de rubriques actives', () {
      final morning = offer('m', departureAt: DateTime(2026, 12, 12, 8));
      final evening = offer('e', departureAt: DateTime(2026, 12, 12, 20));
      final unknown = offer('u');
      const filters = FlightFilters(
        slots: {FlightDaySlot.morning},
        stops: FlightStops.direct,
        maxPrice: 900,
      );
      expect(filters.activeCount, 3);
      expect(
        filters
            .copyWith(stops: FlightStops.any)
            .apply([morning, evening, unknown])
            .map((o) => o.offerPath),
        ['m'],
      );
      expect(const FlightFilters().activeCount, 0);
      expect(const FlightFilters().isFiltering, isFalse);
    });

    test('facettes : tranches présentes et paliers de prix', () {
      final facets = FlightFacets.of([
        offer('a', price: 300, departureAt: DateTime(2026, 12, 12, 8)),
        offer('b', price: 700, departureAt: DateTime(2026, 12, 12, 21)),
      ]);
      expect(facets.slots, {FlightDaySlot.morning, FlightDaySlot.evening});
      expect(facets.priceSteps, [400, 500, 600]);
      expect(FlightFacets.of([offer('a')]).priceSteps, isEmpty);
    });
  });

  group('FlightTabSummary', () {
    test('meilleure offre de chaque onglet, direct absent sans vol direct', () {
      final cheap = offer('cheap', price: 300, minutes: 700);
      final fast = offer('fast', price: 500, minutes: 300);
      final summaries = FlightTabSummary.of([fast, cheap]);
      expect(summaries[FlightResultsTab.cheapest]?.offer, cheap);
      expect(summaries[FlightResultsTab.fastest]?.offer, fast);
      expect(summaries[FlightResultsTab.fastest]?.minutes, 300);
      expect(summaries.containsKey(FlightResultsTab.direct), isFalse);

      final direct = offer('direct', price: 600, transfers: 0, minutes: 360);
      final ranked = FlightTabSummary.rank([
        fast,
        direct,
        cheap,
      ], FlightResultsTab.direct);
      expect(ranked, [direct]);
      expect(
        FlightTabSummary.rank([
          offer('n', minutes: null),
          fast,
        ], FlightResultsTab.fastest).first,
        fast,
      );
    });
  });
}
