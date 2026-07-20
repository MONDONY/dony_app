import 'package:dony/features/matching/data/models/trips_summary_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TripsSummaryModel.fromJson', () {
    test('parse les champs de période', () {
      final model = TripsSummaryModel.fromJson(const {
        'activeTrips': 3,
        'kgSold': 19.0,
        'revenue': 152.46,
        'tripsPublished': 2,
        'parcelsSent': 5,
        'period': '7d',
      });

      expect(model.activeTrips, 3);
      expect(model.kgSold, 19.0);
      expect(model.revenue, 152.46);
      expect(model.tripsPublished, 2);
      expect(model.parcelsSent, 5);
      expect(model.period, '7d');
    });

    test('backend antérieur : repli sur les champs « ThisMonth »', () {
      final model = TripsSummaryModel.fromJson(const {
        'activeTrips': 6,
        'kgSoldThisMonth': 19.5,
        'revenueThisMonth': 152.46,
      });

      expect(model.kgSold, 19.5);
      expect(model.revenue, 152.46);
      // Ces deux-là n'ont pas d'équivalent historique : l'UI doit pouvoir
      // afficher « — » plutôt qu'un zéro trompeur.
      expect(model.tripsPublished, isNull);
      expect(model.parcelsSent, isNull);
    });

    test('les champs de période priment sur les champs historiques', () {
      final model = TripsSummaryModel.fromJson(const {
        'kgSoldThisMonth': 19.5,
        'revenueThisMonth': 152.46,
        'kgSold': 4.0,
        'revenue': 40.0,
      });

      expect(model.kgSold, 4.0);
      expect(model.revenue, 40.0);
    });

    test('une période à zéro reste un zéro, pas un repli', () {
      final model = TripsSummaryModel.fromJson(const {
        'kgSoldThisMonth': 19.5,
        'revenueThisMonth': 152.46,
        'kgSold': 0,
        'revenue': 0,
      });

      expect(model.kgSold, 0);
      expect(model.revenue, 0);
    });

    test('tolère les entiers, les nulls et un JSON vide', () {
      final model = TripsSummaryModel.fromJson(const {
        'activeTrips': 0,
        'kgSoldThisMonth': 0,
        'revenueThisMonth': null,
      });

      expect(model.activeTrips, 0);
      expect(model.kgSold, 0);
      expect(model.revenue, 0);

      final empty = TripsSummaryModel.fromJson(const {});
      expect(empty.activeTrips, 0);
      expect(empty.kgSold, 0);
      expect(empty.revenue, 0);
      expect(empty.period, isNull);
    });
  });
}
