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

  test(
    'route allumée : avion + route à la création, bateau jamais au lot 1',
    () {
      expect(kBoatTripCreationReady, isFalse);
      const a = TransportModesAvailability(road: true, boat: true);
      expect(a.tripCreationModes, [TransportMode.plane, TransportMode.car]);
      expect(a.requestModes, [
        TransportMode.plane,
        TransportMode.boat,
        TransportMode.car,
      ]);
      expect(a.searchModes, a.requestModes);
      expect(a.hasTripChoice, isTrue);
      expect(a.hasRequestChoice, isTrue);
    },
  );

  test('bateau seul : choix à la demande, pas à la création', () {
    const a = TransportModesAvailability(road: false, boat: true);
    expect(a.tripCreationModes, [TransportMode.plane]);
    expect(a.hasTripChoice, isFalse);
    expect(a.requestModes, [TransportMode.plane, TransportMode.boat]);
    expect(a.hasRequestChoice, isTrue);
  });

  test('allowsForTrip suit les modes de création', () {
    const a = TransportModesAvailability(road: true, boat: true);
    expect(a.allowsForTrip(TransportMode.plane), isTrue);
    expect(a.allowsForTrip(TransportMode.car), isTrue);
    expect(a.allowsForTrip(TransportMode.boat), isFalse);
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
