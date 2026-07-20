import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TripsSummaryModel.fromJson', () {
    test(
      'backend antérieur : les champs « ThisMonth » alimentent la période',
      () {
        final model = TripsSummaryModel.fromJson({
          'activeTrips': 6,
          'kgSoldThisMonth': 19.5,
          'revenueThisMonth': 152.46,
        });

        expect(model.activeTrips, 6);
        expect(model.kgSoldForPeriod, 19.5);
        expect(model.revenueForPeriod, 152.46);
        // Sans données de période, l'UI doit savoir qu'elle affiche le mois
        // courant plutôt que l'intervalle demandé.
        expect(model.hasPeriodData, isFalse);
        expect(model.tripsPublished, isNull);
        expect(model.parcelsSent, isNull);
      },
    );

    test('backend à jour : les champs de période priment', () {
      final model = TripsSummaryModel.fromJson({
        'activeTrips': 6,
        'kgSoldThisMonth': 19.5,
        'revenueThisMonth': 152.46,
        'kgSold': 4.0,
        'revenue': 40.0,
        'tripsPublished': 2,
        'parcelsSent': 5,
        'period': '7d',
      });

      expect(model.kgSoldForPeriod, 4.0);
      expect(model.revenueForPeriod, 40.0);
      expect(model.tripsPublished, 2);
      expect(model.parcelsSent, 5);
      expect(model.period, '7d');
      expect(model.hasPeriodData, isTrue);
      // Les anciens champs restent lisibles pour les écrans qui les utilisent.
      expect(model.kgSoldThisMonth, 19.5);
    });

    test('JSON vide → zéros, sans exception', () {
      final model = TripsSummaryModel.fromJson({});

      expect(model.activeTrips, 0);
      expect(model.kgSoldForPeriod, 0);
      expect(model.revenueForPeriod, 0);
      expect(model.hasPeriodData, isFalse);
    });

    test(
      'une période à zéro n\'est pas confondue avec une absence de donnée',
      () {
        final model = TripsSummaryModel.fromJson({
          'kgSoldThisMonth': 19.5,
          'revenueThisMonth': 152.46,
          'kgSold': 0,
          'revenue': 0,
          'period': '7d',
        });

        expect(model.kgSoldForPeriod, 0);
        expect(model.revenueForPeriod, 0);
        expect(model.hasPeriodData, isTrue);
      },
    );
  });
}
