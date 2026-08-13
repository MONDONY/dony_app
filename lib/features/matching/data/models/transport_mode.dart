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
  String get label => switch (this) {
    TransportMode.plane => 'Avion',
    TransportMode.car => 'Voiture',
    TransportMode.train => 'Train',
    TransportMode.bus => 'Bus',
    TransportMode.boat => 'Bateau',
    TransportMode.other => 'Autre',
  };

  IconData get icon => switch (this) {
    TransportMode.plane => Icons.flight_rounded,
    TransportMode.car => Icons.directions_car_rounded,
    TransportMode.train => Icons.train_rounded,
    TransportMode.bus => Icons.directions_bus_rounded,
    TransportMode.boat => Icons.directions_boat_rounded,
    TransportMode.other => Icons.commute_rounded,
  };
}
