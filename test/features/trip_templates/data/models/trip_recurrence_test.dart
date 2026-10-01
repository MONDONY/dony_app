import 'package:dony/features/trip_templates/data/models/trip_recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({int? arrivalDayOffset}) => {
  'id': 'r1',
  'departureCity': 'Paris',
  'arrivalCity': 'Dakar',
  'transportMode': 'PLANE',
  'capacityUnit': 'SUITCASE_23KG',
  'availableKg': 23,
  'pricePerKg': 8,
  'pickupAddress': {'label': 'Paris', 'lat': 48.85, 'lng': 2.35},
  'deliveryAddress': {'label': 'Dakar', 'lat': 14.71, 'lng': -17.46},
  'departureTime': '22:00:00',
  'arrivalTime': '06:30:00',
  'weekdays': '1000000',
  'horizonDays': 14,
  'active': true,
  'arrivalDayOffset': ?arrivalDayOffset,
};

void main() {
  group('TripRecurrence.fromJson', () {
    test('lit le jour d\'arrivée d\'une récurrence de vol de nuit', () {
      final r = TripRecurrence.fromJson(_json(arrivalDayOffset: 1));

      expect(r.arrivalTime, '06:30');
      expect(r.arrivalDayOffset, 1);
    });

    test('back antérieur à V277 : même jour', () {
      expect(TripRecurrence.fromJson(_json()).arrivalDayOffset, 0);
    });
  });
}
