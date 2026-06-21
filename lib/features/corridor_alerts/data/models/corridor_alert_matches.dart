import 'package:dony/features/package_request/data/models/matching_request.dart';
import 'package:equatable/equatable.dart';

import 'alert_direction.dart';
import 'trip_match_model.dart';

/// Résultat typé des matchs d'une alerte. Selon [direction], soit [packages]
/// (colis) soit [trips] (trajets) est rempli — l'autre reste vide.
class CorridorAlertMatches extends Equatable {
  const CorridorAlertMatches({
    required this.direction,
    this.packages = const [],
    this.trips = const [],
  });

  final AlertDirection direction;
  final List<MatchingRequestModel> packages;
  final List<TripMatchModel> trips;

  int get length => direction == AlertDirection.senderWantsTrips
      ? trips.length
      : packages.length;

  bool get isEmpty => length == 0;

  @override
  List<Object?> get props => [direction, packages, trips];
}
