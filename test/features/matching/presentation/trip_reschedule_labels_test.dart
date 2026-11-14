import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_result.dart';
import 'package:dony/features/matching/presentation/trip_reschedule_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('firstReasonFor', () {
    test('avion ou mode absent : FLIGHT_CANCELLED (back prod actuel)', () {
      expect(firstReasonFor(null), TripRescheduleReason.flightCancelled);
      expect(
        firstReasonFor(TransportMode.plane),
        TripRescheduleReason.flightCancelled,
      );
    });

    test('tout autre mode : TRANSPORT_CANCELLED', () {
      for (final m in [
        TransportMode.car,
        TransportMode.bus,
        TransportMode.boat,
        TransportMode.train,
        TransportMode.other,
      ]) {
        expect(firstReasonFor(m), TripRescheduleReason.transportCancelled);
      }
    });
  });

  group('rescheduleReasonLabel', () {
    String label(TripRescheduleReason r, TransportMode? m) =>
        rescheduleReasonLabel(fr, r, m);

    test('FLIGHT_CANCELLED : « Vol annulé » quel que soit le mode', () {
      for (final m in [null, ...TransportMode.values]) {
        expect(label(TripRescheduleReason.flightCancelled, m), 'Vol annulé');
      }
    });

    test('TRANSPORT_CANCELLED : selon le mode', () {
      const r = TripRescheduleReason.transportCancelled;
      expect(label(r, TransportMode.car), 'Panne ou contretemps');
      expect(label(r, TransportMode.bus), 'Panne ou contretemps');
      expect(label(r, TransportMode.boat), 'Transport annulé');
      expect(label(r, TransportMode.train), 'Transport annulé');
      expect(label(r, TransportMode.other), 'Transport annulé');
      expect(label(r, null), 'Transport annulé');
    });

    test('POSTPONED et OTHER : inchangés', () {
      expect(
        label(TripRescheduleReason.postponed, TransportMode.car),
        'Voyage repoussé',
      );
      expect(
        label(TripRescheduleReason.other, TransportMode.car),
        'Autre raison',
      );
    });

    test('anglais', () {
      String l(TripRescheduleReason r, TransportMode? m) =>
          rescheduleReasonLabel(en, r, m);
      expect(l(TripRescheduleReason.flightCancelled, null), 'Flight canceled');
      expect(
        l(TripRescheduleReason.transportCancelled, TransportMode.car),
        'Breakdown or setback',
      );
      expect(
        l(TripRescheduleReason.transportCancelled, TransportMode.boat),
        'Transport canceled',
      );
    });
  });
}
