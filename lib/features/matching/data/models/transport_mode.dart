import 'package:flutter/material.dart';

enum TransportMode { plane, car, train, bus, boat, other }

const Map<TransportMode, String> _wireByEnum = {
  TransportMode.plane: 'PLANE',
  TransportMode.car: 'CAR',
  TransportMode.train: 'TRAIN',
  TransportMode.bus: 'BUS',
  TransportMode.boat: 'BOAT',
  TransportMode.other: 'OTHER',
};

/// Mode d'un trajet ou d'une demande : un mode absent (anciennes données)
/// vaut avion.
TransportMode transportModeOrPlane(TransportMode? mode) =>
    mode ?? TransportMode.plane;

/// Icône SVG (`assets/icons/`) d'un trajet dont le mode est inconnu ou
/// neutre (train, autre).
const String kNeutralTripIconAsset = 'route';

String transportModeToWire(TransportMode mode) => _wireByEnum[mode]!;

TransportMode? transportModeFromWire(String? wire) {
  if (wire == null) {
    return null;
  }
  for (final entry in _wireByEnum.entries) {
    if (entry.value == wire) {
      return entry.key;
    }
  }
  return null;
}

extension TransportModeUI on TransportMode {
  IconData get icon => switch (this) {
    TransportMode.plane => Icons.flight_rounded,
    TransportMode.car => Icons.directions_car_rounded,
    TransportMode.train => Icons.train_rounded,
    TransportMode.bus => Icons.directions_bus_rounded,
    TransportMode.boat => Icons.directions_boat_rounded,
    TransportMode.other => Icons.commute_rounded,
  };

  /// Nom de l'icône Lucide (`DonyIcon`) du mode. Le bus s'affiche comme la
  /// route ; train et autre prennent l'icône neutre.
  String get iconAsset => switch (this) {
    TransportMode.plane => 'plane',
    TransportMode.boat => 'ship',
    TransportMode.car || TransportMode.bus => 'car',
    TransportMode.train || TransportMode.other => kNeutralTripIconAsset,
  };

  /// Emoji du mode (messages partagés, textes bruts).
  String get emoji => switch (this) {
    TransportMode.plane => '✈️',
    TransportMode.boat => '🚢',
    TransportMode.car || TransportMode.bus => '🚗',
    TransportMode.train => '🚆',
    TransportMode.other => '📦',
  };

  /// Route : voiture ou bus (le bus est affiché « Route »).
  bool get isRoad => this == TransportMode.car || this == TransportMode.bus;

  /// Seul l'avion se rattache à des aéroports (codes IATA).
  bool get usesAirportCodes => this == TransportMode.plane;

  /// Mode tel qu'il est regroupé et affiché : le bus compte comme la route.
  TransportMode get displayGroup =>
      this == TransportMode.bus ? TransportMode.car : this;
}
