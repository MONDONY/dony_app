import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/features/flights/bloc/flight_places_cubit.dart';
import 'package:dony/features/flights/data/datasources/flight_locator.dart';
import 'package:dony/features/flights/data/datasources/flight_recent_store.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_recent_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'flights_test_doubles.dart';

class _Locator implements FlightLocator {
  _Locator({required this.can, this.place});

  final bool can;
  final FlightPlace? place;

  @override
  Future<bool> canLocate() async => can;

  @override
  Future<FlightPlace?> nearestCity() async => place;
}

FlightRecentSearch _recent(String from, String to) => FlightRecentSearch(
  origin: FlightPlace(code: from, name: from),
  destination: FlightPlace(code: to, name: to),
  searchedAt: DateTime(2026, 10, 10),
);

void main() {
  late MockFlightsRepository repository;
  late FlightPlacesCubit cubit;

  setUp(() {
    repository = MockFlightsRepository();
    cubit = FlightPlacesCubit(repository, debounce: Duration.zero);
  });

  tearDown(() => cubit.close());

  test('à vide : villes de la diaspora, sans appel', () {
    expect(cubit.state.status, FlightPlacesStatus.suggestions);
    expect(cubit.state.places.map((p) => p.code), contains('ABJ'));
    cubit.termChanged('a');
    verifyNever(() => repository.places(any()));
  });

  test('frappe : résultats du back après le délai', () async {
    when(() => repository.places('abi')).thenAnswer(
      (_) async => const [FlightPlace(code: 'ABJ', name: 'Abidjan')],
    );

    cubit.termChanged(' abi ');
    expect(cubit.state.status, FlightPlacesStatus.loading);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(cubit.state.status, FlightPlacesStatus.loaded);
    expect(cubit.state.places.single.code, 'ABJ');
  });

  test('seule la dernière frappe compte', () async {
    when(() => repository.places(any())).thenAnswer(
      (inv) async => [
        FlightPlace(code: 'XXX', name: inv.positionalArguments.first as String),
      ],
    );

    cubit
      ..termChanged('ab')
      ..termChanged('abu');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    verifyNever(() => repository.places('ab'));
    expect(cubit.state.places.single.name, 'abu');
  });

  test('erreur réseau : état d\'erreur', () async {
    when(() => repository.places(any())).thenThrow(Exception('offline'));

    cubit.termChanged('dak');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(cubit.state.status, FlightPlacesStatus.error);
    expect(cubit.state.error, isNotNull);
  });

  group('récents et position', () {
    final recents = MemoryFlightRecentStore([
      _recent('PAR', 'ABJ'),
      _recent('LYS', 'DKR'),
      _recent('PAR', 'ABJ'),
      _recent('BRU', 'BKO'),
      _recent('MRS', 'DLA'),
    ]);

    test('destinations récentes sans doublon, trois au plus', () async {
      final places = FlightPlacesCubit(repository, recents: recents);
      addTearDown(places.close);

      await places.focusField(departure: false);

      expect(places.state.recent.map((p) => p.code), ['ABJ', 'DKR', 'BKO']);
      expect(places.state.canLocate, isFalse);
    });

    test(
      'champ départ : départs récents et position si déjà permise',
      () async {
        final places = FlightPlacesCubit(
          repository,
          recents: recents,
          locator: _Locator(can: true),
        );
        addTearDown(places.close);

        await places.focusField(departure: true);

        expect(places.state.recent.map((p) => p.code), ['PAR', 'LYS', 'BRU']);
        expect(places.state.canLocate, isTrue);
        // La frappe garde les récents et la position.
        places.termChanged('a');
        expect(places.state.recent, hasLength(3));
        expect(places.state.canLocate, isTrue);
      },
    );

    test('ma position : ville trouvée et tracée', () async {
      final analytics = silentAnalytics();
      const lyon = FlightPlace(code: 'LYS', name: 'Lyon');
      final places = FlightPlacesCubit(
        repository,
        locator: _Locator(can: true, place: lyon),
        analytics: analytics,
      );
      addTearDown(places.close);

      expect(await places.locate(), lyon);
      expect(places.state.locating, isFalse);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.flightsLocationUsed,
          properties: {'found': true},
        ),
      ).called(1);
    });

    test('sans localisateur : rien', () async {
      expect(await cubit.locate(), isNull);
      await cubit.focusField(departure: true);
      expect(cubit.state.canLocate, isFalse);
    });
  });
}
