import 'package:dony/features/matching/data/models/kg_sold_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KgSoldModel.fromJson', () {
    test('lit le total, les colis et les trajets', () {
      final model = KgSoldModel.fromJson({
        'period': '30d',
        'totalKg': 16,
        'parcels': 6,
        'trips': [
          {
            'tripId': 't1',
            'departureCity': 'Paris',
            'arrivalCity': 'Dakar',
            'date': '2026-09-12',
            'parcels': 2,
            'kg': 6.0,
          },
        ],
      });

      expect(model.period, '30d');
      expect(model.totalKg, 16);
      expect(model.parcels, 6);
      final trip = model.trips.single;
      expect(trip.tripId, 't1');
      expect(trip.departureCity, 'Paris');
      expect(trip.arrivalCity, 'Dakar');
      expect(trip.date, DateTime(2026, 9, 12));
      expect(trip.parcels, 2);
      expect(trip.kg, 6.0);
    });

    test('trajets absents → liste vide', () {
      final model = KgSoldModel.fromJson({'period': '12m'});

      expect(model.totalKg, 0);
      expect(model.parcels, 0);
      expect(model.trips, isEmpty);
    });
  });
}
