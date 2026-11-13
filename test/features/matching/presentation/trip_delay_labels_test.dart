import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/matching/data/models/trip_delay_info.dart';
import 'package:dony/features/matching/presentation/trip_delay_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

TripDelayInfo _delay(String reason) => TripDelayInfo(
  reason: reason,
  arrivalDate: DateTime(2027, 1, 11),
  arrivalDateMax: DateTime(2027, 1, 18),
  announcedAt: DateTime(2026, 12, 20),
);

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('tripDelayReasonLabel', () {
    test('bateau : libellés FR et EN', () {
      const boat = TransportMode.boat;
      expect(
        tripDelayReasonLabel(fr, TripDelayReason.portCongestion, boat),
        'Congestion au port',
      );
      expect(tripDelayReasonLabel(fr, TripDelayReason.weather, boat), 'Météo');
      expect(
        tripDelayReasonLabel(fr, TripDelayReason.extendedStopover, boat),
        'Escale prolongée',
      );
      expect(
        tripDelayReasonLabel(fr, TripDelayReason.transportDisruption, boat),
        'Transport perturbé',
      );
      expect(
        tripDelayReasonLabel(fr, TripDelayReason.other, boat),
        'Autre raison',
      );
      expect(
        tripDelayReasonLabel(en, TripDelayReason.portCongestion, boat),
        'Port congestion',
      );
      expect(
        tripDelayReasonLabel(en, TripDelayReason.transportDisruption, boat),
        'Transport disruption',
      );
    });

    test('route et mode inconnu : jamais « escale »', () {
      for (final mode in [
        TransportMode.car,
        TransportMode.bus,
        TransportMode.other,
        null,
      ]) {
        final fr0 = tripDelayReasonLabel(
          fr,
          TripDelayReason.extendedStopover,
          mode,
        );
        expect(fr0, 'Arrêt prolongé', reason: '$mode');
        expect(fr0.toLowerCase(), isNot(contains('escale')));
        expect(
          tripDelayReasonLabel(en, TripDelayReason.extendedStopover, mode),
          'Extended stop',
        );
        // Motif neutre, le même partout.
        expect(
          tripDelayReasonLabel(fr, TripDelayReason.transportDisruption, mode),
          'Transport perturbé',
        );
      }
    });

    test('avion : l\'escale garde son nom', () {
      expect(
        tripDelayReasonLabel(
          fr,
          TripDelayReason.extendedStopover,
          TransportMode.plane,
        ),
        'Escale prolongée',
      );
    });
  });

  group('tripDelayInfoReasonLabel', () {
    test('motif servi par le back', () {
      expect(
        tripDelayInfoReasonLabel(
          fr,
          _delay('PORT_CONGESTION'),
          TransportMode.boat,
        ),
        'Congestion au port',
      );
    });

    test('motif inconnu (back plus récent) : « Autre raison »', () {
      expect(
        tripDelayInfoReasonLabel(fr, _delay('ALIENS'), TransportMode.boat),
        'Autre raison',
      );
      expect(
        tripDelayInfoReasonLabel(en, _delay('ALIENS'), TransportMode.car),
        'Other reason',
      );
    });
  });
}
