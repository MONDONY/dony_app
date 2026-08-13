import 'package:dio/dio.dart';
import 'package:dony/features/city/data/city_datasource.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:dony/features/city/data/popular_corridor_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockCityDatasource extends Mock implements CityDatasource {}

void main() {
  // ── CityModel ─────────────────────────────────────────────────────────────

  group('CityModel', () {
    test('fromJson parse correctement depuis double', () {
      final json = {
        'name': 'Dakar',
        'countryCode': 'SN',
        'countryName': 'Sénégal',
        'lat': 14.71,
        'lng': -17.47,
      };
      final city = CityModel.fromJson(json);
      expect(city.name, 'Dakar');
      expect(city.countryCode, 'SN');
      expect(city.countryName, 'Sénégal');
      expect(city.lat, 14.71);
      expect(city.lng, -17.47);
    });

    test('fromJson cast lat/lng depuis int', () {
      final json = {
        'name': 'Paris',
        'countryCode': 'FR',
        'countryName': 'France',
        'lat': 48,
        'lng': 2,
      };
      final city = CityModel.fromJson(json);
      expect(city.lat, 48.0);
      expect(city.lng, 2.0);
    });

    test('displayLabel retourne "nom, pays"', () {
      const city = CityModel(
        name: 'Dakar',
        countryCode: 'SN',
        countryName: 'Sénégal',
        lat: 14.71,
        lng: -17.47,
      );
      expect(city.displayLabel, 'Dakar, Sénégal');
    });
  });

  // ── PopularCorridorModel ──────────────────────────────────────────────────

  group('PopularCorridorModel', () {
    test('fromJson parse correctement', () {
      final json = {
        'departureCity': 'Paris',
        'departureCountry': 'France',
        'arrivalCity': 'Dakar',
        'arrivalCountry': 'Sénégal',
      };
      final corridor = PopularCorridorModel.fromJson(json);
      expect(corridor.departureCity, 'Paris');
      expect(corridor.departureCountry, 'France');
      expect(corridor.arrivalCity, 'Dakar');
      expect(corridor.arrivalCountry, 'Sénégal');
    });

    test('displayLabel retourne "départ → arrivée"', () {
      const corridor = PopularCorridorModel(
        departureCity: 'Paris',
        departureCountry: 'France',
        arrivalCity: 'Dakar',
        arrivalCountry: 'Sénégal',
      );
      expect(corridor.displayLabel, 'Paris → Dakar');
    });
  });

  // ── CityDatasource ────────────────────────────────────────────────────────

  group('CityDatasource', () {
    late MockDio mockDio;
    late CityDatasource datasource;

    setUp(() {
      mockDio = MockDio();
      datasource = CityDatasource(dio: mockDio);
    });

    test('searchCities retourne une liste de CityModel', () async {
      when(
        () => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/cities/search'),
          data: [
            {
              'name': 'Dakar',
              'countryCode': 'SN',
              'countryName': 'Sénégal',
              'lat': 14.71,
              'lng': -17.47,
            },
          ],
          statusCode: 200,
        ),
      );

      final result = await datasource.searchCities('Dak');
      expect(result.length, 1);
      expect(result.first.name, 'Dakar');
      expect(result.first.countryCode, 'SN');
    });

    test('searchCities retourne liste vide si data null', () async {
      when(
        () => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/cities/search'),
          statusCode: 200,
        ),
      );

      final result = await datasource.searchCities('xyz');
      expect(result, isEmpty);
    });

    test(
      'getPopularCorridors retourne une liste de PopularCorridorModel',
      () async {
        when(
          () => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer(
          (_) async => Response<dynamic>(
            requestOptions: RequestOptions(path: '/cities/corridors/popular'),
            data: [
              {
                'departureCity': 'Paris',
                'departureCountry': 'France',
                'arrivalCity': 'Dakar',
                'arrivalCountry': 'Sénégal',
              },
            ],
            statusCode: 200,
          ),
        );

        final result = await datasource.getPopularCorridors();
        expect(result.length, 1);
        expect(result.first.departureCity, 'Paris');
        expect(result.first.arrivalCity, 'Dakar');
      },
    );

    test('getPopularCorridors retourne liste vide si data null', () async {
      when(
        () => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: '/cities/corridors/popular'),
          statusCode: 200,
        ),
      );

      final result = await datasource.getPopularCorridors();
      expect(result, isEmpty);
    });
  });

  // ── CityRepository ────────────────────────────────────────────────────────

  group('CityRepository', () {
    late MockCityDatasource mockDatasource;
    late CityRepository repository;

    const city = CityModel(
      name: 'Dakar',
      countryCode: 'SN',
      countryName: 'Sénégal',
      lat: 14.71,
      lng: -17.47,
    );

    const corridor = PopularCorridorModel(
      departureCity: 'Paris',
      departureCountry: 'France',
      arrivalCity: 'Dakar',
      arrivalCountry: 'Sénégal',
    );

    setUp(() {
      mockDatasource = MockCityDatasource();
      repository = CityRepository(datasource: mockDatasource);
    });

    test(
      'searchCities délègue au datasource et retourne le résultat',
      () async {
        when(
          () => mockDatasource.searchCities('Dak'),
        ).thenAnswer((_) async => [city]);

        final result = await repository.searchCities('Dak');
        expect(result.length, 1);
        expect(result.first.name, 'Dakar');
        verify(() => mockDatasource.searchCities('Dak')).called(1);
      },
    );

    test(
      'getPopularCorridors délègue au datasource et retourne le résultat',
      () async {
        when(
          () => mockDatasource.getPopularCorridors(),
        ).thenAnswer((_) async => [corridor]);

        final result = await repository.getPopularCorridors();
        expect(result.length, 1);
        expect(result.first.departureCity, 'Paris');
        verify(() => mockDatasource.getPopularCorridors()).called(1);
      },
    );

    test(
      'searchCities retourne liste vide si datasource retourne vide',
      () async {
        when(
          () => mockDatasource.searchCities(any()),
        ).thenAnswer((_) async => []);

        final result = await repository.searchCities('zzz');
        expect(result, isEmpty);
      },
    );
  });
}
