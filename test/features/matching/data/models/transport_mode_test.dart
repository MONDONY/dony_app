import 'dart:io';

import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/presentation/trip_domain_labels.dart';
import 'package:dony/l10n/l10n.dart';
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
      final l = lookupAppLocalizations(AppL10n.fr);
      for (final mode in TransportMode.values) {
        expect(mode.label(l), isNotEmpty);
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

    test('iconAsset par mode', () {
      expect(TransportMode.plane.iconAsset, 'plane');
      expect(TransportMode.boat.iconAsset, 'ship');
      expect(TransportMode.car.iconAsset, 'car');
      expect(TransportMode.bus.iconAsset, 'car');
      expect(TransportMode.train.iconAsset, 'route');
      expect(TransportMode.other.iconAsset, 'route');
    });

    test('chaque iconAsset existe dans assets/icons', () {
      for (final mode in TransportMode.values) {
        expect(
          File('assets/icons/${mode.iconAsset}.svg').existsSync(),
          isTrue,
          reason: mode.name,
        );
      }
      expect(
        File('assets/icons/$kNeutralTripIconAsset.svg').existsSync(),
        isTrue,
      );
    });

    test('emoji par mode', () {
      expect(TransportMode.plane.emoji, '✈️');
      expect(TransportMode.boat.emoji, '🚢');
      expect(TransportMode.car.emoji, '🚗');
      expect(TransportMode.bus.emoji, '🚗');
      expect(TransportMode.train.emoji, '🚆');
      expect(TransportMode.other.emoji, '📦');
    });

    test('bus est affiché comme la route', () {
      expect(TransportMode.bus.displayGroup, TransportMode.car);
      expect(TransportMode.car.displayGroup, TransportMode.car);
      expect(TransportMode.boat.displayGroup, TransportMode.boat);
    });

    test('codes IATA seulement en avion', () {
      expect(TransportMode.plane.usesAirportCodes, isTrue);
      for (final mode in TransportMode.values.where(
        (m) => m != TransportMode.plane,
      )) {
        expect(mode.usesAirportCodes, isFalse, reason: mode.name);
      }
    });

    test('mode absent = avion', () {
      expect(transportModeOrPlane(null), TransportMode.plane);
      expect(transportModeOrPlane(TransportMode.boat), TransportMode.boat);
    });
  });

  group('TransportModeRules', () {
    test('durée max d\'arrivée par mode (miroir de ArrivalRules)', () {
      expect(TransportMode.plane.maxArrivalDays, 3);
      expect(TransportMode.train.maxArrivalDays, 3);
      expect(TransportMode.other.maxArrivalDays, 3);
      expect(TransportMode.car.maxArrivalDays, 14);
      expect(TransportMode.bus.maxArrivalDays, 14);
      expect(TransportMode.boat.maxArrivalDays, 120);
    });

    test('valises : refusées en voiture et en bus seulement', () {
      expect(TransportMode.car.allowsSuitcases, isFalse);
      expect(TransportMode.bus.allowsSuitcases, isFalse);
      for (final m in [
        TransportMode.plane,
        TransportMode.train,
        TransportMode.boat,
        TransportMode.other,
      ]) {
        expect(m.allowsSuitcases, isTrue, reason: m.name);
      }
    });

    test('taille de colis : voiture et bus seulement', () {
      expect(TransportMode.car.hasItemSize, isTrue);
      expect(TransportMode.bus.hasItemSize, isTrue);
      expect(TransportMode.plane.hasItemSize, isFalse);
      expect(TransportMode.boat.hasItemSize, isFalse);
    });

    test('isRoad : voiture et bus', () {
      expect(TransportMode.car.isRoad, isTrue);
      expect(TransportMode.bus.isRoad, isTrue);
      expect(TransportMode.boat.isRoad, isFalse);
      expect(TransportMode.plane.isRoad, isFalse);
    });

    test('mode lourd : voiture, bus et bateau (miroir de WeightLimits)', () {
      expect(TransportMode.car.isHeavy, isTrue);
      expect(TransportMode.bus.isHeavy, isTrue);
      expect(TransportMode.boat.isHeavy, isTrue);
      expect(TransportMode.plane.isHeavy, isFalse);
      expect(TransportMode.train.isHeavy, isFalse);
      expect(TransportMode.other.isHeavy, isFalse);
    });
  });

  group('TripCapacityLimits', () {
    test('capacité max par mode (kilos entiers saisis)', () {
      expect(TripCapacityLimits.maxKgFor(TransportMode.plane), 999);
      expect(TripCapacityLimits.maxKgFor(TransportMode.train), 999);
      expect(TripCapacityLimits.maxKgFor(TransportMode.car), 999999);
      expect(TripCapacityLimits.maxKgFor(TransportMode.bus), 999999);
      expect(TripCapacityLimits.maxKgFor(TransportMode.boat), 999999);
    });
  });
}
