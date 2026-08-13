import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/city/bloc/city_search_bloc.dart';
import 'package:dony/features/city/bloc/city_search_event.dart';
import 'package:dony/features/city/bloc/city_search_state.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCityRepository extends Mock implements CityRepository {}

void main() {
  late MockCityRepository mockRepo;

  setUp(() {
    mockRepo = MockCityRepository();
  });

  const fakeCity = CityModel(
    name: 'Dakar',
    countryCode: 'SN',
    countryName: 'Sénégal',
    lat: 14.71,
    lng: -17.47,
  );

  group('CitySearchBloc', () {
    blocTest<CitySearchBloc, CitySearchState>(
      'état initial est CitySearchInitial',
      build: () => CitySearchBloc(mockRepo),
      verify: (bloc) => expect(bloc.state, isA<CitySearchInitial>()),
    );

    blocTest<CitySearchBloc, CitySearchState>(
      'émet [Loading, Loaded] sur recherche réussie',
      build: () {
        when(
          () => mockRepo.searchCities('Dak'),
        ).thenAnswer((_) async => [fakeCity]);
        return CitySearchBloc(mockRepo);
      },
      act: (bloc) => bloc.add(const CitySearchQueryChanged('Dak')),
      wait: const Duration(milliseconds: 400),
      expect: () => [isA<CitySearchLoading>(), isA<CitySearchLoaded>()],
      verify: (bloc) {
        final loaded = bloc.state as CitySearchLoaded;
        expect(loaded.cities.first.name, 'Dakar');
      },
    );

    blocTest<CitySearchBloc, CitySearchState>(
      'émet [Initial] quand query < 2 chars',
      build: () => CitySearchBloc(mockRepo),
      act: (bloc) => bloc.add(const CitySearchQueryChanged('D')),
      wait: const Duration(milliseconds: 400),
      expect: () => [isA<CitySearchInitial>()],
    );

    blocTest<CitySearchBloc, CitySearchState>(
      'émet [Error] en cas d\'erreur réseau',
      build: () {
        when(
          () => mockRepo.searchCities(any()),
        ).thenThrow(Exception('network error'));
        return CitySearchBloc(mockRepo);
      },
      act: (bloc) => bloc.add(const CitySearchQueryChanged('Paris')),
      wait: const Duration(milliseconds: 400),
      expect: () => [isA<CitySearchLoading>(), isA<CitySearchError>()],
    );

    blocTest<CitySearchBloc, CitySearchState>(
      'émet [Initial] sur CitySearchCleared',
      build: () => CitySearchBloc(mockRepo),
      act: (bloc) => bloc.add(const CitySearchCleared()),
      expect: () => [isA<CitySearchInitial>()],
    );
  });
}
