import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/trip_reschedule_result.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _bidJson({Map<String, dynamic>? reschedule}) => {
  'id': 'b1',
  'announcementId': 'a1',
  'senderId': 's1',
  'weightKg': 5,
  'description': 'Vêtements',
  'status': 'ACCEPTED',
  'createdAt': '2026-10-01T10:00:00',
  'updatedAt': '2026-10-01T10:00:00',
  'reschedule': ?reschedule,
};

void main() {
  group('BidModel.reschedule', () {
    test('lit le dernier report et la décision attendue', () {
      final bid = BidModel.fromJson(
        _bidJson(
          reschedule: {
            'id': 'r1',
            'reason': 'FLIGHT_CANCELLED',
            'note': 'Vol Air Sénégal annulé',
            'previousDepartureDate': '2026-10-09',
            'previousDepartureTime': '22:00:00',
            'newDepartureDate': '2026-10-13',
            'newDepartureTime': '23:00:00',
            'rescheduledAt': '2026-10-01T09:00:00',
            'decisionPending': true,
            'decisionDeadline': '2026-10-12T18:00:00',
          },
        ),
      );

      final r = bid.reschedule!;
      expect(r.reason, 'FLIGHT_CANCELLED');
      expect(r.note, 'Vol Air Sénégal annulé');
      expect(r.previousDepartureDate, DateTime(2026, 10, 9));
      expect(r.newDepartureDate, DateTime(2026, 10, 13));
      expect(r.decisionPending, isTrue);
      expect(r.decisionDeadline, DateTime(2026, 10, 12, 18));
    });

    test('back antérieur au report : champ absent, rien à afficher', () {
      expect(BidModel.fromJson(_bidJson()).reschedule, isNull);
    });
  });

  group('TripRescheduleResult', () {
    test('lit le résumé du report', () {
      final r = TripRescheduleResult.fromJson({
        'rescheduleId': 'r1',
        'rescheduleCount': 1,
        'remainingReschedules': 1,
        'parcelsAwaitingDecision': 2,
        'requestsInformed': 3,
      });
      expect(r.remainingReschedules, 1);
      expect(r.parcelsAwaitingDecision, 2);
      expect(r.requestsInformed, 3);
    });

    test('motifs : valeurs du back, inconnu = nul', () {
      expect(
        TripRescheduleReason.fromWire('POSTPONED'),
        TripRescheduleReason.postponed,
      );
      expect(TripRescheduleReason.fromWire('NOPE'), isNull);
      expect(TripRescheduleReason.flightCancelled.wire, 'FLIGHT_CANCELLED');
    });
  });
}
