import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/flights/bloc/flight_search_cubit.dart';
import 'package:dony/features/flights/data/datasources/flight_recent_store.dart';
import 'package:dony/features/flights/data/models/flight_filters.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_recent_search.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'flights_test_doubles.dart';

const _lille = FlightPlace(code: 'LIL', name: 'Lille');
const _abidjan = FlightPlace(code: 'ABJ', name: 'Abidjan');

FlightSearchResult _result(List<FlightOffer> offers, {String? path}) =>
    FlightSearchResult(
      originCode: 'LIL',
      destinationCode: 'ABJ',
      roundTrip: false,
      currency: 'EUR',
      offers: offers,
      searchPath: path,
    );

/// Historique dont l'écriture échoue : la recherche doit aboutir quand même.
class _BrokenStore extends MemoryFlightRecentStore {
  @override
  Future<void> write(List<FlightRecentSearch> entries) =>
      Future.error(StateError('disque plein'));
}

void main() {
  late MockFlightsRepository repository;
  late MockAnalyticsService analytics;
  late MemoryFlightRecentStore store;
  late FlightSearchCubit cubit;
  final now = DateTime(2026, 10, 12, 10);

  setUpAll(() => registerFallbackValue(const FlightSearchQuery()));

  setUp(() {
    repository = MockFlightsRepository();
    analytics = silentAnalytics();
    store = MemoryFlightRecentStore();
    cubit = FlightSearchCubit(
      repository,
      analytics,
      recents: store,
      clock: () => now,
    );
  });

  tearDown(() => cubit.close());

  void route() => cubit
    ..setOrigin(_lille)
    ..setDestination(_abidjan);

  group('aller-retour', () {
    test('le sélecteur garde le choix et oublie le retour en aller simple', () {
      cubit.setRoundTrip(true);
      expect(cubit.state.query.roundTrip, isTrue);
      expect(cubit.state.query.needsReturnDate, isTrue);

      cubit.setDates(
        FlightWhen.day(DateTime(2026, 12, 12)),
        FlightWhen.day(DateTime(2027, 1, 3)),
      );
      expect(cubit.state.query.isRoundTrip, isTrue);

      cubit.setRoundTrip(false);
      expect(cubit.state.query.returnDate, isNull);
      expect(cubit.state.query.roundTrip, isFalse);
    });

    test('départ et arrivée choisis ensemble', () {
      cubit.setRoute(origin: _lille, destination: _abidjan);
      expect(cubit.state.query.origin, _lille);
      expect(cubit.state.query.destination, _abidjan);
    });
  });

  group('historique des recherches', () {
    test(
      'une recherche réussie est mémorisée avec son prix le plus bas',
      () async {
        when(() => repository.search(any())).thenAnswer(
          (_) async =>
              _result([offer('a', price: 500), offer('b', price: 389)]),
        );
        route();

        await cubit.search();

        final recent = cubit.state.recents.single;
        expect(recent.lowestPrice, 389);
        expect(recent.currency, 'EUR');
        expect(recent.searchedAt, now);
        expect(store.read(), hasLength(1));
      },
    );

    test('recherche sans résultat : mémorisée sans prix', () async {
      when(() => repository.search(any())).thenAnswer((_) async => _result([]));
      route();
      await cubit.search();
      expect(cubit.state.recents.single.lowestPrice, isNull);
    });

    test(
      'un historique en panne n\'empêche pas d\'afficher les résultats',
      () async {
        final broken = FlightSearchCubit(
          repository,
          analytics,
          recents: _BrokenStore(),
        );
        addTearDown(broken.close);
        when(
          () => repository.search(any()),
        ).thenAnswer((_) async => _result([offer('a')]));
        broken
          ..setOrigin(_lille)
          ..setDestination(_abidjan);

        await broken.search();

        expect(broken.state.status, FlightSearchStatus.loaded);
        expect(broken.state.recents, isEmpty);
      },
    );

    test('l\'historique est relu à l\'ouverture de l\'onglet', () {
      final saved = FlightRecentSearch(
        origin: _lille,
        destination: _abidjan,
        searchedAt: DateTime(2026, 10),
      );
      final reopened = FlightSearchCubit(
        repository,
        analytics,
        recents: MemoryFlightRecentStore([saved]),
      );
      addTearDown(reopened.close);
      expect(reopened.state.recents, [saved]);
    });

    test('rouvrir une recherche récente la relance et la trace', () async {
      final saved = FlightRecentSearch(
        origin: _lille,
        destination: _abidjan,
        departure: FlightWhen.day(DateTime(2026, 12, 12)),
        searchedAt: DateTime(2026, 10, 9, 10),
      );
      await store.write([saved]);
      final withHistory = FlightSearchCubit(
        repository,
        analytics,
        recents: store,
        clock: () => now,
      );
      addTearDown(withHistory.close);
      FlightSearchQuery? sent;
      when(() => repository.search(any())).thenAnswer((inv) async {
        sent = inv.positionalArguments.first as FlightSearchQuery;
        return _result([offer('a')]);
      });

      await withHistory.openRecent(saved);

      expect(sent?.origin, _lille);
      expect(sent?.departure, FlightWhen.day(DateTime(2026, 12, 12)));
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.flightsRecentSearchOpened,
          properties: {'position': 0, 'age_days': 3},
        ),
      ).called(1);
    });

    test('effacer vide l\'historique et le trace', () async {
      when(
        () => repository.search(any()),
      ).thenAnswer((_) async => _result([offer('a')]));
      route();
      await cubit.search();

      await cubit.clearRecents();

      expect(cubit.state.recents, isEmpty);
      expect(store.read(), isEmpty);
      verify(
        () => analytics.logEvent(AnalyticsEvents.flightsRecentSearchesCleared),
      ).called(1);
    });
  });

  group('onglets de tri', () {
    final cheap = offer('cheap', price: 300, minutes: 700);
    final fast = offer('fast', price: 500, minutes: 300);
    final direct = offer('direct', price: 600, transfers: 0, minutes: 360);

    Future<void> loaded(List<FlightOffer> offers) async {
      when(
        () => repository.search(any()),
      ).thenAnswer((_) async => _result(offers));
      route();
      await cubit.search();
    }

    test('chaque onglet range la liste filtrée et se trace', () async {
      await loaded([direct, fast, cheap]);
      expect(cubit.state.visibleOffers.first, cheap);

      cubit.selectTab(FlightResultsTab.fastest);
      expect(cubit.state.visibleOffers.first, fast);

      cubit.selectTab(FlightResultsTab.direct);
      expect(cubit.state.visibleOffers, [direct]);
      expect(cubit.state.tabSummaries[FlightResultsTab.direct]?.price, 600);

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.flightsSortTabChanged,
          properties: {'tab': 'direct'},
        ),
      ).called(1);

      // Même onglet retouché : rien ne change, rien ne part.
      cubit.selectTab(FlightResultsTab.direct);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.flightsSortTabChanged,
          properties: {'tab': 'cheapest'},
        ),
      );
    });

    test('« Direct » sans vol direct retombe sur « Le moins cher »', () async {
      await loaded([fast, cheap]);
      cubit.selectTab(FlightResultsTab.direct);
      expect(cubit.state.effectiveTab, FlightResultsTab.cheapest);
      expect(cubit.state.visibleOffers.first, cheap);
    });

    test('les onglets suivent les filtres', () async {
      await loaded([direct, fast, cheap]);
      cubit.applyFilters(const FlightFilters(stops: FlightStops.direct));
      expect(
        cubit.state.tabSummaries[FlightResultsTab.cheapest]?.offer,
        direct,
      );
      expect(cubit.state.filteredOffers, [direct]);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.flightsFilterApplied,
          properties: {
            'sort': 'cheapest',
            'stops': 'direct',
            'airlines_count': 0,
            'gates_count': 0,
            'price_range': false,
            'slots_count': 0,
          },
        ),
      ).called(1);
    });

    test('une nouvelle recherche revient à « Le moins cher »', () async {
      await loaded([direct, fast, cheap]);
      cubit.selectTab(FlightResultsTab.fastest);
      await cubit.search();
      expect(cubit.state.tab, FlightResultsTab.cheapest);
    });
  });

  group('écran « Aucun vol »', () {
    test('« Paris, mêmes dates » relance depuis Paris', () async {
      FlightSearchQuery? sent;
      when(() => repository.search(any())).thenAnswer((inv) async {
        sent = inv.positionalArguments.first as FlightSearchQuery;
        return _result([]);
      });
      route();
      cubit.setDates(FlightWhen.day(DateTime(2026, 10, 12)), null);

      await cubit.searchFromParis();

      expect(sent?.origin?.code, 'PAR');
      expect(sent?.departure, FlightWhen.day(DateTime(2026, 10, 12)));
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.flightsEmptySuggestionTapped,
          properties: {'kind': 'paris'},
        ),
      ).called(1);
    });

    test('« Tout le mois » passe les jours en mois entiers', () async {
      FlightSearchQuery? sent;
      when(() => repository.search(any())).thenAnswer((inv) async {
        sent = inv.positionalArguments.first as FlightSearchQuery;
        return _result([]);
      });
      route();
      cubit.setDates(
        FlightWhen.day(DateTime(2026, 10, 12)),
        FlightWhen.day(DateTime(2026, 10, 31)),
      );

      await cubit.searchWholeMonth();

      expect(sent?.departure, FlightWhen.month(DateTime(2026, 10)));
      expect(sent?.returnDate, FlightWhen.month(DateTime(2026, 10)));
      expect(sent?.departure?.wholeMonth, isTrue);
    });

    test('les autres sorties se tracent sans rien relancer', () {
      cubit.trackSuggestion(FlightEmptySuggestion.aviasales);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.flightsEmptySuggestionTapped,
          properties: {'kind': 'aviasales'},
        ),
      ).called(1);
      verifyNever(() => repository.search(any()));
    });
  });

  test(
    'l\'offre la plus rapide de toutes ignore les durées inconnues',
    () async {
      final pending = Completer<FlightSearchResult>();
      when(() => repository.search(any())).thenAnswer((_) => pending.future);
      route();
      final running = cubit.search();
      expect(cubit.state.status, FlightSearchStatus.loading);
      pending.complete(_result([offer('n', minutes: null), offer('t')]));
      await running;
      expect(cubit.state.fastest?.offerPath, 't');
    },
  );
}
