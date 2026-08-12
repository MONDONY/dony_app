import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/tracking/bloc/scan_hub_selectors.dart';
import 'package:flutter_test/flutter_test.dart';

AnnouncementModel _trip(String id, String status, DateTime date) =>
    AnnouncementModel(
      id: id,
      travelerId: 'traveler-1',
      status: status,
      departureDate: date,
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      availableKg: 10,
      totalKg: 20,
      pricePerKg: 5,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

BidModel _bid(String status) => BidModel(
      id: 'b-$status',
      announcementId: 'a',
      senderId: 's',
      status: status,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('selectScannableTrips', () {
    test('IN_PROGRESS triés par date, avant les ACTIVE/FULL triés par date', () {
      final trips = [
        _trip('1', 'ACTIVE', DateTime(2026, 7, 1)),
        _trip('2', 'IN_PROGRESS', DateTime(2026, 6, 20)),
        _trip('3', 'IN_PROGRESS', DateTime(2026, 6, 10)),
        _trip('4', 'FULL', DateTime(2026, 6, 28)),
      ];
      final result = selectScannableTrips(trips);
      expect(result.map((t) => t.id), ['3', '2', '4', '1']);
    });

    test('un seul trajet scannable → liste à un élément', () {
      final trips = [_trip('1', 'IN_PROGRESS', DateTime(2026, 6, 20))];
      expect(selectScannableTrips(trips).map((t) => t.id), ['1']);
    });

    test('aucun trajet scannable → liste vide', () {
      expect(
        selectScannableTrips([_trip('1', 'CANCELLED', DateTime(2026, 1, 1))]),
        isEmpty,
      );
      expect(selectScannableTrips(const []), isEmpty);
    });
  });

  group('computeScanProgress', () {
    test('confirmés et scannés départ dérivés du statut', () {
      final bids = [
        _bid('ACCEPTED'),
        _bid('HANDED_OVER'),
        _bid('IN_TRANSIT'),
        _bid('COMPLETED'),
        _bid('REJECTED'),
        _bid('PENDING'),
      ];
      final p = computeScanProgress(bids);
      expect(p.confirmedColis, 4); // ACCEPTED+HANDED_OVER+IN_TRANSIT+COMPLETED
      expect(p.scannedDepart, 3); // HANDED_OVER+IN_TRANSIT+COMPLETED
    });

    test('liste vide → zéros', () {
      final p = computeScanProgress(const []);
      expect(p.confirmedColis, 0);
      expect(p.scannedDepart, 0);
    });
  });

  group('nextRequiredStep', () {
    test('ACCEPTED → DEPART', () {
      expect(nextRequiredStep(_bid('ACCEPTED')), 'DEPART');
    });
    test('HANDED_OVER → TRANSIT', () {
      expect(nextRequiredStep(_bid('HANDED_OVER')), 'TRANSIT');
    });
    test('IN_TRANSIT → ARRIVEE', () {
      expect(nextRequiredStep(_bid('IN_TRANSIT')), 'ARRIVEE');
    });
    test('COMPLETED → null (tout est déjà scanné)', () {
      expect(nextRequiredStep(_bid('COMPLETED')), isNull);
    });
  });

  group('confirmedColis', () {
    test('garde les statuts confirmés, exclut PENDING/REJECTED/CANCELLED', () {
      final accepted = _bid('ACCEPTED');
      final handedOver = _bid('HANDED_OVER');
      final inTransit = _bid('IN_TRANSIT');
      final completed = _bid('COMPLETED');
      final pending = _bid('PENDING');
      final rejected = _bid('REJECTED');
      final cancelled = _bid('CANCELLED');
      final result = confirmedColis([
        accepted,
        handedOver,
        inTransit,
        completed,
        pending,
        rejected,
        cancelled,
      ]);
      expect(
        result,
        containsAll(<BidModel>[accepted, handedOver, inTransit, completed]),
      );
      expect(result, isNot(contains(pending)));
      expect(result, isNot(contains(rejected)));
      expect(result, isNot(contains(cancelled)));
      expect(result.length, 4);
    });

    test('liste vide → liste vide', () {
      expect(confirmedColis(const []), isEmpty);
    });
  });

  group('colisStepProgress', () {
    test('ACCEPTED → aucune étape faite', () {
      final p = colisStepProgress(_bid('ACCEPTED'));
      expect(p.depart, isFalse);
      expect(p.transit, isFalse);
      expect(p.arrivee, isFalse);
    });
    test('HANDED_OVER → départ fait seulement', () {
      final p = colisStepProgress(_bid('HANDED_OVER'));
      expect(p.depart, isTrue);
      expect(p.transit, isFalse);
      expect(p.arrivee, isFalse);
    });
    test('IN_TRANSIT → départ + transit faits', () {
      final p = colisStepProgress(_bid('IN_TRANSIT'));
      expect(p.depart, isTrue);
      expect(p.transit, isTrue);
      expect(p.arrivee, isFalse);
    });
    test('COMPLETED → tout fait', () {
      final p = colisStepProgress(_bid('COMPLETED'));
      expect(p.depart, isTrue);
      expect(p.transit, isTrue);
      expect(p.arrivee, isTrue);
    });
  });
}
