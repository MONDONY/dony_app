// Tests du magasin des villes récentes.
//
// Il était couvert à 0 % : tous les tests d'écran l'enregistrent en factice
// (voir test/helpers/mock_recent_city_store.dart), donc sa vraie logique de
// sérialisation, de déduplication et de troncature n'était jamais exercée.
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/data/recent_city_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

class MockBox extends Mock implements Box<dynamic> {}

class MockHiveService extends Mock implements HiveService {}

const _paris = CityModel(
  name: 'Paris',
  countryCode: 'FR',
  countryName: 'France',
  lat: 48.85,
  lng: 2.35,
);

const _lyon = CityModel(
  name: 'Lyon',
  countryCode: 'FR',
  countryName: 'France',
  lat: 45.76,
  lng: 4.83,
);

const _dakar = CityModel(
  name: 'Dakar',
  countryCode: 'SN',
  countryName: 'Sénégal',
  lat: 14.72,
  lng: -17.47,
);

/// Homonyme de [_paris] dans un autre pays : la déduplication porte sur le
/// couple (nom, code pays), pas sur le seul nom.
const _parisTexas = CityModel(
  name: 'Paris',
  countryCode: 'US',
  countryName: 'États-Unis',
  lat: 33.66,
  lng: -95.55,
);

void main() {
  late MockBox box;
  late MockHiveService hive;
  late RecentCityStore store;

  setUp(() {
    box = MockBox();
    hive = MockHiveService();
    when(() => hive.userPrefs).thenReturn(box);
    when(
      () => box.put(any<dynamic>(), any<dynamic>()),
    ).thenAnswer((_) async {});
    store = RecentCityStore(hive);
  });

  /// Ce que Hive rendrait pour [role] : la liste brute déjà sérialisée.
  void seed(CityFieldRole role, List<CityModel> cities) {
    final key = role == CityFieldRole.departure
        ? HiveService.kRecentDepartureCities
        : HiveService.kRecentArrivalCities;
    when(
      () => box.get(key, defaultValue: any<dynamic>(named: 'defaultValue')),
    ).thenReturn(cities.map((c) => c.toJson()).toList());
  }

  /// Villes passées au dernier `put` pour [role].
  List<Map<String, dynamic>> lastWrite(CityFieldRole role) {
    final key = role == CityFieldRole.departure
        ? HiveService.kRecentDepartureCities
        : HiveService.kRecentArrivalCities;
    final captured =
        verify(() => box.put(key, captureAny<dynamic>())).captured.last as List;
    return captured.cast<Map<String, dynamic>>();
  }

  group('read', () {
    test('rend une liste vide quand rien n\'a été mémorisé', () {
      when(
        () => box.get(
          any<dynamic>(),
          defaultValue: any<dynamic>(named: 'defaultValue'),
        ),
      ).thenReturn(const <dynamic>[]);

      expect(store.read(CityFieldRole.departure), isEmpty);
    });

    test('désérialise les villes mémorisées dans l\'ordre', () {
      seed(CityFieldRole.departure, [_paris, _lyon]);

      final cities = store.read(CityFieldRole.departure);

      expect(cities.map((c) => c.name), ['Paris', 'Lyon']);
      expect(cities.first.countryCode, 'FR');
      expect(cities.first.lat, 48.85);
    });

    test('départ et arrivée lisent deux clés distinctes', () {
      seed(CityFieldRole.departure, [_paris]);
      seed(CityFieldRole.arrival, [_dakar]);

      expect(store.read(CityFieldRole.departure).single.name, 'Paris');
      expect(store.read(CityFieldRole.arrival).single.name, 'Dakar');
    });

    test('ignore les entrées qui ne sont pas des Map', () {
      when(
        () => box.get(
          any<dynamic>(),
          defaultValue: any<dynamic>(named: 'defaultValue'),
        ),
      ).thenReturn(<dynamic>['corrompu', 42, _paris.toJson()]);

      expect(store.read(CityFieldRole.departure).map((c) => c.name), ['Paris']);
    });
  });

  group('add', () {
    test('place la nouvelle ville en tête', () async {
      seed(CityFieldRole.departure, [_lyon]);

      await store.add(CityFieldRole.departure, _paris);

      expect(lastWrite(CityFieldRole.departure).map((m) => m['name']), [
        'Paris',
        'Lyon',
      ]);
    });

    test('remonte une ville déjà présente sans la dupliquer', () async {
      seed(CityFieldRole.departure, [_lyon, _paris, _dakar]);

      await store.add(CityFieldRole.departure, _paris);

      expect(lastWrite(CityFieldRole.departure).map((m) => m['name']), [
        'Paris',
        'Lyon',
        'Dakar',
      ]);
    });

    test('deux villes homonymes de pays différents coexistent', () async {
      seed(CityFieldRole.departure, [_parisTexas]);

      await store.add(CityFieldRole.departure, _paris);

      final written = lastWrite(CityFieldRole.departure);
      expect(written.map((m) => m['name']), ['Paris', 'Paris']);
      expect(written.map((m) => m['countryCode']), ['FR', 'US']);
    });

    test('tronque à maxEntries en évinçant la plus ancienne', () async {
      seed(CityFieldRole.departure, [_paris, _lyon, _parisTexas]);

      await store.add(CityFieldRole.departure, _dakar);

      final written = lastWrite(CityFieldRole.departure);
      expect(written, hasLength(RecentCityStore.maxEntries));
      expect(written.map((m) => m['name']), ['Dakar', 'Paris', 'Lyon']);
    });

    test('écrit sous la clé du rôle visé', () async {
      seed(CityFieldRole.arrival, const []);
      when(
        () => box.get(
          any<dynamic>(),
          defaultValue: any<dynamic>(named: 'defaultValue'),
        ),
      ).thenReturn(const <dynamic>[]);

      await store.add(CityFieldRole.arrival, _dakar);

      verify(
        () => box.put(HiveService.kRecentArrivalCities, any<dynamic>()),
      ).called(1);
      verifyNever(
        () => box.put(HiveService.kRecentDepartureCities, any<dynamic>()),
      );
    });
  });
}
