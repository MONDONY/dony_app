import 'package:dony/features/ai_form_draft/data/ai_city_resolver.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCityRepository extends Mock implements CityRepository {}

const _paris = CityModel(
  name: 'Paris',
  countryCode: 'FR',
  countryName: 'France',
  lat: 48.85,
  lng: 2.35,
);
const _parisTexas = CityModel(
  name: 'Paris',
  countryCode: 'US',
  countryName: 'États-Unis',
  lat: 33.66,
  lng: -95.55,
);
const _saintLouis = CityModel(
  name: 'Saint-Louis',
  countryCode: 'SN',
  countryName: 'Sénégal',
  lat: 16.02,
  lng: -16.49,
);

void main() {
  late _MockCityRepository repository;
  late AiCityResolver resolver;

  setUp(() {
    repository = _MockCityRepository();
    resolver = AiCityResolver(repository);
  });

  test(
    'nom égal sans casse ni accents ni tiret : ville du catalogue',
    () async {
      when(
        () => repository.searchCities('saint louis'),
      ).thenAnswer((_) async => const [_saintLouis]);
      expect(await resolver.resolve('saint louis'), _saintLouis);
    },
  );

  test('plusieurs homonymes : le code pays dit tranche', () async {
    when(
      () => repository.searchCities('Paris'),
    ).thenAnswer((_) async => const [_parisTexas, _paris]);
    expect(await resolver.resolve('Paris', countryCode: 'FR'), _paris);
    expect(await resolver.resolve('Paris'), _parisTexas);
  });

  test('aucun nom égal (suggestion approchante) : inconnue', () async {
    when(
      () => repository.searchCities('Pari'),
    ).thenAnswer((_) async => const [_paris]);
    expect(await resolver.resolve('Pari'), isNull);
  });

  test('recherche en échec ou nom trop court : inconnue', () async {
    when(() => repository.searchCities('Dakar')).thenThrow(Exception('réseau'));
    expect(await resolver.resolve('Dakar'), isNull);
    expect(await resolver.resolve(' D '), isNull);
    verifyNever(() => repository.searchCities('D'));
  });

  group('resolveInto', () {
    test('ville trouvée : nom et code pays du catalogue', () async {
      when(
        () => repository.searchCities('paris'),
      ).thenAnswer((_) async => const [_paris]);
      final draft = <String, Object?>{
        'departureCity': 'paris',
        'departureCountryCode': 'FR',
      };
      final ok = await resolver.resolveInto(
        draft,
        cityKey: 'departureCity',
        countryKey: 'departureCountryCode',
      );
      expect(ok, isTrue);
      expect(draft, {'departureCity': 'Paris', 'departureCountryCode': 'FR'});
    });

    test('ville introuvable : clés vidées, faux', () async {
      when(
        () => repository.searchCities('Atlantis'),
      ).thenAnswer((_) async => const []);
      final draft = <String, Object?>{
        'arrivalCity': 'Atlantis',
        'arrivalCountryCode': 'XX',
      };
      final ok = await resolver.resolveInto(
        draft,
        cityKey: 'arrivalCity',
        countryKey: 'arrivalCountryCode',
      );
      expect(ok, isFalse);
      expect(draft, {'arrivalCity': null, 'arrivalCountryCode': null});
    });

    test('ville absente : rien à vérifier, vrai', () async {
      final draft = <String, Object?>{'arrivalCity': null};
      expect(await resolver.resolveInto(draft, cityKey: 'arrivalCity'), isTrue);
      verifyNever(() => repository.searchCities(any()));
    });
  });
}
