import 'package:dony/features/profile/data/models/pro_stats_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> baseJson() => {
    'monthlyRevenue': 200.0,
    'totalRevenue': 402.0,
    'monthlyTrips': 3,
    'monthlyParcelsDelivered': 12,
    'acceptanceRate': 0.95,
    'averageRating': 4.8,
    'topDestinations': [
      {'from': 'Paris', 'to': 'Dakar', 'count': 5},
    ],
  };

  group('ProStatsModel.fromJson — multidevise', () {
    test('parse la devise servie et les ventilations', () {
      final json = baseJson()
        ..addAll({
          'currency': 'EUR',
          'monthlyRevenueByCurrency': [
            {'currency': 'EUR', 'amount': 100.0},
            {'currency': 'XOF', 'amount': 65596.0},
          ],
          'totalRevenueByCurrency': [
            {'currency': 'EUR', 'amount': 100.0},
            {'currency': 'XOF', 'amount': 65596.0},
          ],
        });

      final model = ProStatsModel.fromJson(json);

      expect(model.currency, 'EUR');
      expect(model.isMultiCurrency, isTrue);
      expect(model.monthlyRevenueByCurrency, hasLength(2));
      expect(model.monthlyRevenueByCurrency.first.currency, 'EUR');
      expect(model.monthlyRevenueByCurrency.last.amount, 65596.0);
    });

    test('une seule devise encaissée → pas multidevise', () {
      final json = baseJson()
        ..addAll({
          'currency': 'EUR',
          'totalRevenueByCurrency': [
            {'currency': 'EUR', 'amount': 402.0},
          ],
        });

      expect(ProStatsModel.fromJson(json).isMultiCurrency, isFalse);
    });

    test('backend pas encore déployé (champs absents) → repli silencieux', () {
      // L'écran garde alors son comportement d'avant : devise du cache local,
      // pas de « environ ».
      final model = ProStatsModel.fromJson(baseJson());

      expect(model.currency, isNull);
      expect(model.monthlyRevenueByCurrency, isEmpty);
      expect(model.isMultiCurrency, isFalse);
      expect(model.totalRevenue, 402.0);
    });
  });
}
