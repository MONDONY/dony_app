import 'package:dony/features/flights/bloc/flight_places_cubit.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'flights_test_doubles.dart';

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
}
