import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinkedTripSummary.fromJson', () {
    test('parse tous les champs présents', () {
      final t = LinkedTripSummary.fromJson(const {
        'announcementId': 'ann-1',
        'departureCity': 'Paris',
        'arrivalCity': 'Dakar',
        'departureDate': '2026-06-12',
        'departureTime': '14:30',
        'transportMode': 'PLANE',
        'pickupAddressLabel': 'Gare de Lyon, Paris',
        'deliveryAddressLabel': 'Plateau, Dakar',
        'availableKg': 18,
        'description': 'Remise possible la veille.',
      });

      expect(t.announcementId, 'ann-1');
      expect(t.departureCity, 'Paris');
      expect(t.arrivalCity, 'Dakar');
      expect(t.departureDate, '2026-06-12');
      expect(t.departureTime, '14:30');
      expect(t.transportMode, 'PLANE');
      expect(t.pickupAddressLabel, 'Gare de Lyon, Paris');
      expect(t.deliveryAddressLabel, 'Plateau, Dakar');
      expect(t.availableKg, 18);
      expect(t.description, 'Remise possible la veille.');
    });

    test('retourne null pour les champs optionnels absents', () {
      final t = LinkedTripSummary.fromJson(const {'announcementId': 'ann-2'});

      expect(t.announcementId, 'ann-2');
      expect(t.departureCity, isNull);
      expect(t.arrivalCity, isNull);
      expect(t.departureDate, isNull);
      expect(t.departureTime, isNull);
      expect(t.transportMode, isNull);
      expect(t.pickupAddressLabel, isNull);
      expect(t.deliveryAddressLabel, isNull);
      expect(t.availableKg, isNull);
      expect(t.description, isNull);
    });

    test('availableKg accepte un num et le convertit en int', () {
      final t = LinkedTripSummary.fromJson(const {
        'announcementId': 'ann-3',
        'availableKg': 20.0,
      });
      expect(t.availableKg, 20);
    });

    test('deux instances aux mêmes valeurs sont égales (Equatable)', () {
      const json = {'announcementId': 'ann-4', 'departureCity': 'Lyon'};
      expect(LinkedTripSummary.fromJson(json),
          LinkedTripSummary.fromJson(json));
    });
  });
}
