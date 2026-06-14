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
  group('selectScannableTrip', () {
    test('priorité au IN_PROGRESS le plus proche', () {
      final trips = [
        _trip('1', 'ACTIVE', DateTime(2026, 7, 1)),
        _trip('2', 'IN_PROGRESS', DateTime(2026, 6, 20)),
        _trip('3', 'IN_PROGRESS', DateTime(2026, 6, 10)),
      ];
      expect(selectScannableTrip(trips)?.id, '3');
    });

    test('sinon le prochain ACTIVE/FULL', () {
      final trips = [
        _trip('1', 'COMPLETED', DateTime(2026, 1, 1)),
        _trip('2', 'ACTIVE', DateTime(2026, 7, 5)),
        _trip('3', 'FULL', DateTime(2026, 6, 28)),
      ];
      expect(selectScannableTrip(trips)?.id, '3');
    });

    test('aucun trajet scannable → null', () {
      expect(
        selectScannableTrip([_trip('1', 'CANCELLED', DateTime(2026, 1, 1))]),
        isNull,
      );
      expect(selectScannableTrip(const []), isNull);
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
}
