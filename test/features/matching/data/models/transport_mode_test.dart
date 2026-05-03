import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransportMode wire JSON', () {
    test('round-trip for each value', () {
      const wireNames = {
        TransportMode.plane: 'PLANE',
        TransportMode.car: 'CAR',
        TransportMode.train: 'TRAIN',
        TransportMode.bus: 'BUS',
        TransportMode.boat: 'BOAT',
        TransportMode.other: 'OTHER',
      };
      for (final entry in wireNames.entries) {
        expect(transportModeFromWire(entry.value), entry.key);
        expect(transportModeToWire(entry.key), entry.value);
      }
    });

    test('returns null for unknown wire value', () {
      expect(transportModeFromWire('BIKE'), isNull);
      expect(transportModeFromWire(null), isNull);
    });
  });

  group('TransportMode UI', () {
    test('label is non-empty for every value', () {
      for (final mode in TransportMode.values) {
        expect(mode.label, isNotEmpty);
      }
    });

    test('icons match the Material rounded set', () {
      expect(TransportMode.plane.icon, Icons.flight_rounded);
      expect(TransportMode.car.icon, Icons.directions_car_rounded);
      expect(TransportMode.train.icon, Icons.train_rounded);
      expect(TransportMode.bus.icon, Icons.directions_bus_rounded);
      expect(TransportMode.boat.icon, Icons.directions_boat_rounded);
      expect(TransportMode.other.icon, Icons.commute_rounded);
    });
  });
}
