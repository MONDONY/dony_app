import 'package:dony/features/package_request/data/models/linked_trip_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinkedTripSummary', () {
    test('fromJson parses all fields', () {
      final json = {
        'announcementId': 'ann-1',
        'departureCity': 'Paris',
        'arrivalCity': 'Dakar',
        'departureDate': '2026-08-15',
        'departureTime': '10:30',
        'transportMode': 'PLANE',
        'pickupAddressLabel': '10 rue de Rivoli',
        'deliveryAddressLabel': 'Aéroport DSS',
        'availableKg': 10,
        'description': 'Valise cabine',
      };
      final model = LinkedTripSummary.fromJson(json);
      expect(model.announcementId, 'ann-1');
      expect(model.departureCity, 'Paris');
      expect(model.arrivalCity, 'Dakar');
      expect(model.departureDate, '2026-08-15');
      expect(model.departureTime, '10:30');
      expect(model.transportMode, 'PLANE');
      expect(model.pickupAddressLabel, '10 rue de Rivoli');
      expect(model.deliveryAddressLabel, 'Aéroport DSS');
      expect(model.availableKg, 10);
      expect(model.description, 'Valise cabine');
    });

    test('fromJson parses nullable fields as null', () {
      final json = {
        'announcementId': 'ann-2',
        'departureCity': 'Lyon',
        'arrivalCity': 'Abidjan',
        'availableKg': 5,
      };
      final model = LinkedTripSummary.fromJson(json);
      expect(model.departureDate, isNull);
      expect(model.departureTime, isNull);
      expect(model.transportMode, isNull);
      expect(model.pickupAddressLabel, isNull);
      expect(model.deliveryAddressLabel, isNull);
      expect(model.description, isNull);
    });

    test('fromJson uses 0 when availableKg is null', () {
      final json = {
        'announcementId': 'ann-3',
        'departureCity': 'Marseille',
        'arrivalCity': 'Douala',
      };
      final model = LinkedTripSummary.fromJson(json);
      expect(model.availableKg, 0);
    });

    test('Equatable: equal when all props match', () {
      final a = LinkedTripSummary.fromJson({
        'announcementId': 'ann-1',
        'departureCity': 'Paris',
        'arrivalCity': 'Dakar',
        'availableKg': 10,
      });
      final b = LinkedTripSummary.fromJson({
        'announcementId': 'ann-1',
        'departureCity': 'Paris',
        'arrivalCity': 'Dakar',
        'availableKg': 10,
      });
      expect(a, equals(b));
    });

    test('Equatable: not equal when announcementId differs', () {
      final a = LinkedTripSummary.fromJson({
        'announcementId': 'ann-1',
        'departureCity': 'Paris',
        'arrivalCity': 'Dakar',
        'availableKg': 10,
      });
      final b = LinkedTripSummary.fromJson({
        'announcementId': 'ann-2',
        'departureCity': 'Paris',
        'arrivalCity': 'Dakar',
        'availableKg': 10,
      });
      expect(a, isNot(equals(b)));
    });
  });
}
