import 'package:dony/core/config/transport_modes_flag.dart';
import 'package:dony/features/matching/presentation/widgets/create_announcement/trip_form_step.dart';
import 'package:flutter_test/flutter_test.dart';

const _roadOpen = TransportModesAvailability(road: true, boat: false);

void main() {
  group('tripFormSteps', () {
    test('5 étapes avec Mode, 4 sans', () {
      expect(tripFormSteps(showModeStep: true).first, TripFormStep.mode);
      expect(tripFormSteps(showModeStep: true), TripFormStep.values);
      expect(tripFormSteps(showModeStep: false), [
        TripFormStep.trajet,
        TripFormStep.capacite,
        TripFormStep.prix,
        TripFormStep.conditions,
      ]);
    });
  });

  group('TripFormStep.wire', () {
    test('valeurs figées', () {
      expect(
        [for (final s in TripFormStep.values) s.wire],
        ['mode', 'trajet', 'capacite', 'prix', 'conditions'],
      );
    });

    test('fromWire relit chaque valeur, null sinon', () {
      for (final s in TripFormStep.values) {
        expect(TripFormStep.fromWire(s.wire), s);
      }
      expect(TripFormStep.fromWire(null), isNull);
      expect(TripFormStep.fromWire('inconnue'), isNull);
    });
  });

  group('showModeStepFor', () {
    test('modification : jamais d\'étape Mode', () {
      expect(
        showModeStepFor(
          isEdit: true,
          isLocked: false,
          lockedModeKnown: false,
          modes: _roadOpen,
        ),
        isFalse,
      );
    });

    test('trajet dédié sur demande « peu importe » : étape Mode', () {
      expect(
        showModeStepFor(
          isEdit: false,
          isLocked: true,
          lockedModeKnown: false,
          modes: _roadOpen,
        ),
        isTrue,
      );
    });

    test('trajet dédié sur demande au mode connu : pas d\'étape Mode', () {
      expect(
        showModeStepFor(
          isEdit: false,
          isLocked: true,
          lockedModeKnown: true,
          modes: _roadOpen,
        ),
        isFalse,
      );
    });

    test('trajet dédié sans choix possible : pas d\'étape Mode', () {
      expect(
        showModeStepFor(
          isEdit: false,
          isLocked: true,
          lockedModeKnown: false,
          modes: TransportModesAvailability.planeOnly,
        ),
        isFalse,
      );
    });

    test('création : étape Mode seulement s\'il y a un choix', () {
      expect(
        showModeStepFor(
          isEdit: false,
          isLocked: false,
          lockedModeKnown: false,
          modes: _roadOpen,
        ),
        isTrue,
      );
      expect(
        showModeStepFor(
          isEdit: false,
          isLocked: false,
          lockedModeKnown: false,
          modes: TransportModesAvailability.planeOnly,
        ),
        isFalse,
      );
    });
  });
}
