import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TripsSummaryModel', () {
    test('fromJson parse les trois champs', () {
      final model = TripsSummaryModel.fromJson(const {
        'activeTrips': 3,
        'kgSoldThisMonth': 19.0,
        'revenueThisMonth': 152.46,
      });

      expect(model.activeTrips, 3);
      expect(model.kgSoldThisMonth, 19.0);
      expect(model.revenueThisMonth, 152.46);
    });

    test('fromJson tolère les nombres entiers et les nulls', () {
      final model = TripsSummaryModel.fromJson(const {
        'activeTrips': 0,
        'kgSoldThisMonth': 0,
        'revenueThisMonth': null,
      });

      expect(model.activeTrips, 0);
      expect(model.kgSoldThisMonth, 0);
      expect(model.revenueThisMonth, 0);
    });
  });
}
