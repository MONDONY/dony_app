import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/flights/bloc/flight_search_cubit.dart';
import 'package:dony/features/flights/data/datasources/flight_recent_store.dart';
import 'package:dony/features/flights/data/models/flight_deal.dart';
import 'package:dony/features/flights/data/models/flight_defaults.dart';
import 'package:dony/features/flights/data/models/flight_filters.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_recent_search.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'flights_test_doubles.dart';

const _paris = FlightPlace(code: 'PAR', name: 'Paris');
const _abidjan = FlightPlace(code: 'ABJ', name: 'Abidjan');

void main() {
  late MockFlightsRepository repository;
  late MockAnalyticsService analytics;
  late FlightSearchCubit cubit;

  setUpAll(() => registerFallbackValue(const FlightSearchQuery()));

  setUp(() {
    repository = MockFlightsRepository();
    analytics = silentAnalytics();
    cubit = FlightSearchCubit(repository, analytics);
  });

  tearDown(() => cubit.close());

  test(
    'le préremplissage remplit départ et arrivée et trace sa source',
    () async {
      when(() => repository.defaults()).thenAnswer(
        (_) async => const FlightDefaults(
          source: 'search',
          origin: _paris,
          destination: _abidjan,
        ),
      );

      await cubit.loadDefaults();

      expect(cubit.state.query.origin, _paris);
      expect(cubit.state.query.destination, _abidjan);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.flightsPrefillApplied,
          properties: {'source': 'search'},
        ),
      ).called(1);
    },
  );

  test('le préremplissage ne remplace jamais une saisie', () async {
    when(() => repository.defaults()).thenAnswer(
      (_) async => const FlightDefaults(
        source: 'corridor',
        origin: _abidjan,
        destination: _paris,
      ),
    );
    cubit.setOrigin(_paris);

    await cubit.loadDefaults();

    expect(cubit.state.query.origin, _paris);
    expect(cubit.state.query.destination, isNull);
  });

  test('un échec du préremplissage laisse le formulaire vide', () async {
    when(() => repository.defaults()).thenThrow(Exception('offline'));

    await cubit.loadDefaults();

    expect(cubit.state.query, const FlightSearchQuery());
  });

  test('serveur sans destination : le départ habituel suffit', () async {
    when(() => repository.defaults()).thenAnswer(
      (_) async => const FlightDefaults(source: 'corridor', origin: _paris),
    );

    await cubit.loadDefaults();

    expect(cubit.state.query.origin, _paris);
    expect(cubit.state.query.destination, isNull);
  });

  test('serveur muet : repli sur la dernière recherche du téléphone', () async {
    when(
      () => repository.defaults(),
    ).thenAnswer((_) async => FlightDefaults.none);
    final local = FlightSearchCubit(
      repository,
      analytics,
      recents: MemoryFlightRecentStore([
        FlightRecentSearch(
          origin: _abidjan,
          destination: _paris,
          searchedAt: DateTime(2026, 10),
        ),
      ]),
    );
    addTearDown(local.close);

    await local.loadDefaults();

    expect(local.state.query.origin, _abidjan);
    expect(local.state.query.destination, _paris);
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.flightsPrefillApplied,
        properties: {'source': 'recent'},
      ),
    ).called(1);
  });

  test(
    'échec réseau : la dernière recherche du téléphone prend le relais',
    () async {
      when(() => repository.defaults()).thenThrow(Exception('offline'));
      final local = FlightSearchCubit(
        repository,
        analytics,
        recents: MemoryFlightRecentStore([
          FlightRecentSearch(
            origin: _paris,
            destination: _abidjan,
            searchedAt: DateTime(2026, 10),
          ),
        ]),
      );
      addTearDown(local.close);

      await local.loadDefaults();

      expect(local.state.query.origin, _paris);
    },
  );

  test('recherche incomplète : rien ne part', () async {
    cubit.setOrigin(_paris);
    await cubit.search();

    verifyNever(() => repository.search(any()));
    expect(cubit.state.status, FlightSearchStatus.editing);
  });

  test(
    'recherche réussie : résultats, filtres remis à zéro, event sans ville',
    () async {
      when(() => repository.search(any())).thenAnswer(
        (_) async => FlightSearchResult(
          originCode: 'PAR',
          destinationCode: 'ABJ',
          roundTrip: false,
          currency: 'EUR',
          offers: [offer('a', price: 500, minutes: 380), offer('b')],
        ),
      );
      cubit
        ..setOrigin(_paris)
        ..setDestination(_abidjan)
        ..setDates(FlightWhen.day(DateTime(2026, 12, 12)), null)
        ..applyFilters(const FlightFilters(stops: FlightStops.direct));

      await cubit.search();

      expect(cubit.state.status, FlightSearchStatus.loaded);
      expect(cubit.state.filters, const FlightFilters());
      expect(cubit.state.cheapest?.offerPath, 'b');
      expect(cubit.state.fastest?.offerPath, 'a');
      expect(cubit.state.visibleOffers.map((o) => o.offerPath), ['b', 'a']);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.flightsSearchSubmitted,
          properties: {
            'round_trip': false,
            'direct_only': false,
            'date_mode': 'day',
            'from_deal': false,
            'count': 2,
          },
        ),
      ).called(1);
    },
  );

  test('erreur du back : état d\'erreur et code tracé', () async {
    when(() => repository.search(any())).thenThrow(
      DioException(
        requestOptions: RequestOptions(),
        error: const NetworkException('down', code: 'flights-unavailable'),
      ),
    );
    cubit
      ..setOrigin(_paris)
      ..setDestination(_abidjan);

    await cubit.search();

    expect(cubit.state.status, FlightSearchStatus.error);
    expect((cubit.state.error as AppException?)?.code, 'flights-unavailable');
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.flightsSearchFailed,
        properties: {'reason': 'flights-unavailable'},
      ),
    ).called(1);
  });

  test('inverser échange départ et arrivée', () {
    cubit
      ..setOrigin(_paris)
      ..setDestination(_abidjan)
      ..swap();

    expect(cubit.state.query.origin, _abidjan);
    expect(cubit.state.query.destination, _paris);
  });

  test('un bon plan lance la recherche de son trajet sur son mois', () async {
    FlightSearchQuery? sent;
    when(() => repository.search(any())).thenAnswer((inv) async {
      sent = inv.positionalArguments.first as FlightSearchQuery;
      return const FlightSearchResult(
        originCode: 'PAR',
        destinationCode: 'ABJ',
        roundTrip: false,
        currency: 'EUR',
        offers: [],
      );
    });

    await cubit.openDeal(
      FlightDeal(
        offer: offer('d', departureAt: DateTime(2026, 12, 14, 9)),
        medianPrice: 600,
        discountPercent: 32,
      ),
      personalized: true,
    );

    expect(sent?.origin?.code, 'PAR');
    expect(sent?.departure, FlightWhen.month(DateTime(2026, 12)));
    verify(
      () => analytics.logEvent(
        AnalyticsEvents.flightsDealOpened,
        properties: {'discount_percent': 32, 'personalized': true},
      ),
    ).called(1);
  });

  test('retour au formulaire : résultats effacés, saisie conservée', () async {
    when(() => repository.search(any())).thenAnswer(
      (_) async => const FlightSearchResult(
        originCode: 'PAR',
        destinationCode: 'ABJ',
        roundTrip: false,
        currency: 'EUR',
        offers: [],
      ),
    );
    cubit
      ..setOrigin(_paris)
      ..setDestination(_abidjan);
    await cubit.search();

    cubit.backToForm();

    expect(cubit.state.showsResults, isFalse);
    expect(cubit.state.result, isNull);
    expect(cubit.state.query.origin, _paris);
  });

  test(
    'une réponse arrivée après le retour au formulaire est ignorée',
    () async {
      final response = Completer<FlightSearchResult>();
      when(() => repository.search(any())).thenAnswer((_) => response.future);
      cubit
        ..setOrigin(_paris)
        ..setDestination(_abidjan)
        ..setDates(FlightWhen.day(DateTime(2026, 12, 12)), null);

      final pending = cubit.search();
      cubit.backToForm();
      response.complete(
        const FlightSearchResult(
          originCode: 'PAR',
          destinationCode: 'ABJ',
          roundTrip: false,
          currency: 'EUR',
          offers: [],
        ),
      );
      await pending;

      expect(cubit.state.status, FlightSearchStatus.editing);
      expect(cubit.state.result, isNull);
      verifyNever(
        () => analytics.logEvent(
          AnalyticsEvents.flightsSearchSubmitted,
          properties: any(named: 'properties'),
        ),
      );
    },
  );

  test('seule la recherche la plus récente s\'affiche', () async {
    final first = Completer<FlightSearchResult>();
    final second = Completer<FlightSearchResult>();
    final responses = [first, second];
    when(
      () => repository.search(any()),
    ).thenAnswer((_) => responses.removeAt(0).future);
    cubit
      ..setOrigin(_paris)
      ..setDestination(_abidjan)
      ..setDates(FlightWhen.day(DateTime(2026, 12, 12)), null);

    final a = cubit.search();
    final b = cubit.search();
    second.complete(
      FlightSearchResult(
        originCode: 'PAR',
        destinationCode: 'ABJ',
        roundTrip: false,
        currency: 'EUR',
        offers: [offer('recent')],
      ),
    );
    first.completeError(_dioError());
    await Future.wait([a, b]);

    expect(cubit.state.status, FlightSearchStatus.loaded);
    expect(cubit.state.result?.offers.single.offerPath, contains('recent'));
  });
}

DioException _dioError() => DioException(
  requestOptions: RequestOptions(),
  error: const NetworkException('x', code: 'flights-provider-error'),
);
