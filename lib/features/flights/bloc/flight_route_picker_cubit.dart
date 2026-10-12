import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ouverture de l'écran « Où allez-vous ? » : le trajet déjà saisi et le
/// champ à remplir.
class FlightRoutePickerArgs {
  const FlightRoutePickerArgs({
    this.origin,
    this.destination,
    required this.departure,
  });

  final FlightPlace? origin;
  final FlightPlace? destination;

  /// Vrai : la ville de départ est en cours de saisie.
  final bool departure;
}

/// Trajet rendu par l'écran de choix des villes.
class FlightRoutePick extends Equatable {
  const FlightRoutePick({this.origin, this.destination});

  final FlightPlace? origin;
  final FlightPlace? destination;

  @override
  List<Object?> get props => [origin, destination];
}

class FlightRoutePickerState extends Equatable {
  const FlightRoutePickerState({
    this.origin,
    this.destination,
    required this.departureActive,
    this.done = false,
    this.changed = false,
  });

  final FlightPlace? origin;
  final FlightPlace? destination;

  /// Champ en cours de saisie : départ (vrai) ou destination.
  final bool departureActive;

  /// Les deux villes sont choisies après une sélection : l'écran se ferme.
  final bool done;

  /// Au moins une ville a été choisie depuis l'ouverture.
  final bool changed;

  FlightRoutePick get pick =>
      FlightRoutePick(origin: origin, destination: destination);

  @override
  List<Object?> get props => [
    origin,
    destination,
    departureActive,
    done,
    changed,
  ];
}

/// État de l'écran « Où allez-vous ? » : les deux champs empilés, celui qui
/// est actif, et la fermeture une fois le trajet complet.
class FlightRoutePickerCubit extends Cubit<FlightRoutePickerState> {
  FlightRoutePickerCubit(FlightRoutePickerArgs args)
    : super(
        FlightRoutePickerState(
          origin: args.origin,
          destination: args.destination,
          departureActive: args.departure,
        ),
      );

  /// Rend actif le champ départ (vrai) ou destination.
  void activate({required bool departure}) => emit(
    FlightRoutePickerState(
      origin: state.origin,
      destination: state.destination,
      departureActive: departure,
      changed: state.changed,
    ),
  );

  /// Remplit le champ actif. Si l'autre champ est vide (ou porte la même
  /// ville), il devient actif ; sinon le trajet est complet et l'écran se
  /// ferme.
  void choose(FlightPlace place) {
    final departure = state.departureActive;
    var origin = departure ? place : state.origin;
    var destination = departure ? state.destination : place;
    if (origin?.code == destination?.code) {
      if (departure) {
        destination = null;
      } else {
        origin = null;
      }
    }
    final other = departure ? destination : origin;
    emit(
      FlightRoutePickerState(
        origin: origin,
        destination: destination,
        departureActive: other == null ? !departure : departure,
        done: other != null,
        changed: true,
      ),
    );
  }
}
