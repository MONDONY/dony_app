import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TripsSummaryModel.fromJson', () {
    test('lit la devise d\'affichage et le drapeau de conversion', () {
      final model = TripsSummaryModel.fromJson({
        'activeTrips': 1,
        'kgSold': 16,
        'revenue': 1418.7,
        'tripsPublished': 4,
        'parcelsSent': 0,
        'period': '30d',
        'revenueCurrency': 'EUR',
        'revenueConverted': true,
      });

      expect(model.revenueCurrency, 'EUR');
      expect(model.revenueConverted, isTrue);
      expect(model.isRevenueConverted, isTrue);
    });

    test('tolère un backend qui n\'envoie pas encore ces champs', () {
      final model = TripsSummaryModel.fromJson({
        'activeTrips': 1,
        'kgSold': 16,
        'revenue': 1418.7,
      });

      expect(model.revenueCurrency, isNull);
      expect(model.revenueConverted, isNull);
      // Sans information, aucun « ≈ » : on n'affirme pas une conversion.
      expect(model.isRevenueConverted, isFalse);
    });

    test('garde le repli sur les anciens noms de champs', () {
      final model = TripsSummaryModel.fromJson({
        'activeTrips': 2,
        'kgSoldThisMonth': 3,
        'revenueThisMonth': 40,
      });

      expect(model.kgSold, 3);
      expect(model.revenue, 40);
    });
  });
}
