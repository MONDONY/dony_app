import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(resetTransportModesForTest);

  test('repli : avion seul tant que rien n\'est chargé', () {
    expect(transportModes, TransportModesAvailability.planeOnly);
    expect(
      transportModesListenable.value,
      TransportModesAvailability.planeOnly,
    );
  });

  test('avion seul : aucun choix, ni à la création ni à la demande', () {
    const a = TransportModesAvailability.planeOnly;
    expect(a.tripCreationModes, [TransportMode.plane]);
    expect(a.requestModes, [TransportMode.plane]);
    expect(a.searchModes, [TransportMode.plane]);
    expect(a.hasTripChoice, isFalse);
    expect(a.hasRequestChoice, isFalse);
  });

  test('route et bateau allumés : les trois modes à la création (lot 3)', () {
    expect(kBoatTripCreationReady, isTrue);
    const a = TransportModesAvailability(road: true, boat: true);
    expect(a.tripCreationModes, [
      TransportMode.plane,
      TransportMode.car,
      TransportMode.boat,
    ]);
    expect(a.requestModes, [
      TransportMode.plane,
      TransportMode.boat,
      TransportMode.car,
    ]);
    expect(a.searchModes, a.requestModes);
    expect(a.hasTripChoice, isTrue);
    expect(a.hasRequestChoice, isTrue);
  });

  test('bateau seul allumé : avion et bateau à la création', () {
    const a = TransportModesAvailability(road: false, boat: true);
    expect(a.tripCreationModes, [TransportMode.plane, TransportMode.boat]);
    expect(a.hasTripChoice, isTrue);
    expect(a.requestModes, [TransportMode.plane, TransportMode.boat]);
    expect(a.hasRequestChoice, isTrue);
  });

  test('modèles et trajet dédié : jamais le bateau (C16, A9)', () {
    const a = TransportModesAvailability(road: true, boat: true);
    expect(a.templateModes, [TransportMode.plane, TransportMode.car]);
    expect(a.withoutBoat.tripCreationModes, a.templateModes);
    expect(a.withoutBoat.boat, isFalse);
    expect(a.withoutBoat.road, isTrue);
    expect(a.hasTemplateChoice, isTrue);
    const boatOnly = TransportModesAvailability(road: false, boat: true);
    expect(boatOnly.templateModes, [TransportMode.plane]);
    expect(boatOnly.hasTemplateChoice, isFalse);
  });

  test('bateau éteint : jamais proposé à la création', () {
    const a = TransportModesAvailability(road: true, boat: false);
    expect(a.tripCreationModes, [TransportMode.plane, TransportMode.car]);
    expect(a.allowsForTrip(TransportMode.boat), isFalse);
  });

  test('allowsForTrip suit les modes de création', () {
    const a = TransportModesAvailability(road: true, boat: true);
    expect(a.allowsForTrip(TransportMode.plane), isTrue);
    expect(a.allowsForTrip(TransportMode.car), isTrue);
    expect(a.allowsForTrip(TransportMode.boat), isTrue);
    expect(a.allowsForTrip(TransportMode.train), isFalse);
    expect(
      TransportModesAvailability.planeOnly.allowsForTrip(TransportMode.car),
      isFalse,
    );
  });

  test('JSON partiel ou non booléen : faux', () {
    final partial = TransportModesAvailability.fromJson(const {'road': true});
    expect(partial.road, isTrue);
    expect(partial.boat, isFalse);
    expect(
      TransportModesAvailability.fromJson(const {}),
      TransportModesAvailability.planeOnly,
    );
    expect(
      TransportModesAvailability.fromJson(const {'road': 'true', 'boat': 1}),
      TransportModesAvailability.planeOnly,
    );
  });

  test('égalité par valeur', () {
    expect(
      const TransportModesAvailability(road: true, boat: false),
      const TransportModesAvailability(road: true, boat: false),
    );
    expect(
      const TransportModesAvailability(road: true, boat: false) ==
          const TransportModesAvailability(road: false, boat: true),
      isFalse,
    );
  });

  test(
    'setTransportModes notifie et resetTransportModesForTest remet avion seul',
    () {
      var notified = 0;
      void listener() => notified++;
      transportModesListenable.addListener(listener);
      setTransportModes(
        const TransportModesAvailability(road: true, boat: false),
      );
      transportModesListenable.removeListener(listener);
      expect(notified, 1);
      expect(transportModes.road, isTrue);
      resetTransportModesForTest();
      expect(transportModes, TransportModesAvailability.planeOnly);
    },
  );
}
