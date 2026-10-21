import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/utils/trip_capacity.dart';
import 'package:flutter_test/flutter_test.dart';

AnnouncementModel _ann({
  required String unit,
  required double total,
  required double available,
}) => AnnouncementModel(
  id: 'a1',
  travelerId: 't1',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 6, 15),
  availableKg: available,
  totalKg: total,
  capacityUnit: unit,
  pricePerKg: 12,
  status: 'ACTIVE',
  createdAt: DateTime(2026, 5),
  updatedAt: DateTime(2026, 5),
);

void main() {
  group('TripCapacity.fromAnnouncement', () {
    test('2 valises de 23 kg', () {
      final c = TripCapacity.fromAnnouncement(
        _ann(unit: 'SUITCASE_23KG', total: 46, available: 46),
      )!;
      expect(c.count, 2);
      expect(c.unitKg, 23);
      expect(c.totalKg, 46);
    });

    test('3 valises de 32 kg', () {
      final c = TripCapacity.fromAnnouncement(
        _ann(unit: 'SUITCASE_32KG', total: 96, available: 56),
      )!;
      expect(c.count, 3);
      expect(c.unitKg, 32);
    });

    test('personnalisé, kg libre : pas de valises', () {
      expect(
        TripCapacity.fromAnnouncement(
          _ann(unit: 'CUSTOM', total: 30, available: 30),
        ),
        isNull,
      );
      expect(
        TripCapacity.fromAnnouncement(
          _ann(unit: 'KG_FREE', total: 1, available: 1),
        ),
        isNull,
      );
    });

    test('total non multiple de la valise ou nul : repli en kilos', () {
      expect(
        TripCapacity.fromAnnouncement(
          _ann(unit: 'SUITCASE_23KG', total: 50, available: 50),
        ),
        isNull,
      );
      expect(
        TripCapacity.fromAnnouncement(
          _ann(unit: 'SUITCASE_23KG', total: 0, available: 0),
        ),
        isNull,
      );
    });

    test('availableKg est borné au total', () {
      final c = TripCapacity.fromAnnouncement(
        _ann(unit: 'SUITCASE_23KG', total: 23, available: 99),
      )!;
      expect(c.availableKg, 23);
    });
  });

  group('TripCapacity.remainingPerSuitcase', () {
    test('rien de réservé : valises pleines de place', () {
      final c = TripCapacity.fromAnnouncement(
        _ann(unit: 'SUITCASE_23KG', total: 46, available: 46),
      )!;
      expect(c.remainingPerSuitcase, [23, 23]);
    });

    test('14 kg réservés : la première valise se remplit en premier', () {
      final c = TripCapacity.fromAnnouncement(
        _ann(unit: 'SUITCASE_23KG', total: 46, available: 32),
      )!;
      expect(c.remainingPerSuitcase, [9, 23]);
    });

    test('30 kg réservés : première pleine, deuxième entamée', () {
      final c = TripCapacity.fromAnnouncement(
        _ann(unit: 'SUITCASE_23KG', total: 46, available: 16),
      )!;
      expect(c.remainingPerSuitcase, [0, 16]);
    });

    test('tout réservé : plus aucun kilo', () {
      final c = TripCapacity.fromAnnouncement(
        _ann(unit: 'SUITCASE_32KG', total: 64, available: 0),
      )!;
      expect(c.remainingPerSuitcase, [0, 0]);
    });
  });
}
