import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/flights/data/datasources/flight_recent_store.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_recent_search.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/map_backed_box.dart';

class _MockHive extends Mock implements HiveService {}

class _MockBox extends Mock implements Box<dynamic> {}

FlightRecentSearch _search(String to, {int day = 12, int minutes = 0}) =>
    FlightRecentSearch(
      origin: const FlightPlace(code: 'PAR', name: 'Paris'),
      destination: FlightPlace(code: to, name: to),
      departure: FlightWhen.day(DateTime(2026, 12, day)),
      searchedAt: DateTime(2026, 10, 10, 9, minutes),
    );

void main() {
  late Map<String, dynamic> stored;
  late _MockHive hive;
  late HiveFlightRecentStore store;

  setUp(() {
    stored = {};
    hive = _MockHive();
    final box = mapBackedBox(stored);
    when(() => hive.userPrefs).thenReturn(box);
    store = HiveFlightRecentStore(hive);
  });

  test('vide au départ', () {
    expect(store.read(), isEmpty);
  });

  test('la plus récente en tête, sans doublon, cinq au plus', () async {
    for (final to in ['ABJ', 'DKR', 'BKO', 'DLA', 'COO', 'OUA']) {
      await store.add(_search(to));
    }
    await store.add(_search('DKR', minutes: 5));

    final codes = store.read().map((r) => r.destination.code).toList();
    expect(codes, ['DKR', 'OUA', 'COO', 'DLA', 'BKO']);
    expect(stored[HiveService.kFlightRecentSearches], hasLength(5));
  });

  test('mêmes villes à d\'autres dates : deux entrées', () async {
    await store.add(_search('ABJ'));
    await store.add(_search('ABJ', day: 20));
    expect(store.read(), hasLength(2));
  });

  test('effacer vide l\'historique', () async {
    await store.add(_search('ABJ'));
    await store.clear();
    expect(store.read(), isEmpty);
  });

  test(
    'contenu corrompu ou boîte fermée : liste vide, jamais d\'erreur',
    () async {
      stored[HiveService.kFlightRecentSearches] = ['x', 3];
      expect(store.read(), isEmpty);

      final broken = _MockBox();
      when(() => broken.get(any())).thenThrow(HiveError('fermée'));
      when(() => broken.put(any(), any())).thenThrow(HiveError('fermée'));
      when(() => hive.userPrefs).thenReturn(broken);
      expect(store.read(), isEmpty);
      await expectLater(store.write([_search('ABJ')]), completes);
    },
  );

  test('stockage en mémoire', () async {
    final memory = MemoryFlightRecentStore([_search('ABJ')]);
    await memory.add(_search('DKR'));
    expect(memory.read().map((r) => r.destination.code), ['DKR', 'ABJ']);
  });
}
