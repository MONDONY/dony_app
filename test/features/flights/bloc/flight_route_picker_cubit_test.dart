import 'package:dony/features/flights/bloc/flight_route_picker_cubit.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:flutter_test/flutter_test.dart';

const _paris = FlightPlace(code: 'PAR', name: 'Paris');
const _abidjan = FlightPlace(code: 'ABJ', name: 'Abidjan');
const _dakar = FlightPlace(code: 'DKR', name: 'Dakar');

void main() {
  test('destination choisie, départ déjà connu : trajet complet', () {
    final cubit = FlightRoutePickerCubit(
      const FlightRoutePickerArgs(origin: _paris, departure: false),
    );
    addTearDown(cubit.close);

    cubit.choose(_abidjan);

    expect(cubit.state.done, isTrue);
    expect(cubit.state.changed, isTrue);
    expect(
      cubit.state.pick,
      const FlightRoutePick(origin: _paris, destination: _abidjan),
    );
  });

  test(
    'départ choisi, destination vide : le champ destination devient actif',
    () {
      final cubit = FlightRoutePickerCubit(
        const FlightRoutePickerArgs(departure: true),
      );
      addTearDown(cubit.close);

      cubit.choose(_paris);

      expect(cubit.state.done, isFalse);
      expect(cubit.state.departureActive, isFalse);
      expect(cubit.state.origin, _paris);

      cubit.choose(_dakar);
      expect(cubit.state.done, isTrue);
      expect(cubit.state.pick.destination, _dakar);
    },
  );

  test(
    'même ville des deux côtés : l\'autre champ se vide et devient actif',
    () {
      final cubit = FlightRoutePickerCubit(
        const FlightRoutePickerArgs(
          origin: _paris,
          destination: _abidjan,
          departure: true,
        ),
      );
      addTearDown(cubit.close);

      cubit.choose(_abidjan);

      expect(cubit.state.origin, _abidjan);
      expect(cubit.state.destination, isNull);
      expect(cubit.state.departureActive, isFalse);
      expect(cubit.state.done, isFalse);

      final reverse = FlightRoutePickerCubit(
        const FlightRoutePickerArgs(
          origin: _paris,
          destination: _abidjan,
          departure: false,
        ),
      );
      addTearDown(reverse.close);
      reverse.choose(_paris);
      expect(reverse.state.origin, isNull);
      expect(reverse.state.departureActive, isTrue);
    },
  );

  test('changer de champ garde les villes déjà choisies', () {
    final cubit = FlightRoutePickerCubit(
      const FlightRoutePickerArgs(origin: _paris, departure: false),
    );
    addTearDown(cubit.close);

    cubit.activate(departure: true);

    expect(cubit.state.departureActive, isTrue);
    expect(cubit.state.origin, _paris);
    expect(cubit.state.changed, isFalse);
  });
}
