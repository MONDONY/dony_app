import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter_test/flutter_test.dart';

AnnouncementModel _ann({required double pricePerKg, double? pricePerKgDisplay}) =>
    AnnouncementModel(
      id: 'a',
      travelerId: 't',
      departureCity: 'Paris',
      arrivalCity: 'Dakar',
      departureDate: DateTime(2026, 7, 1),
      availableKg: 10,
      totalKg: 10,
      pricePerKg: pricePerKg,
      pricePerKgDisplay: pricePerKgDisplay,
      status: 'OPEN',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

void main() {
  group('dony_pricing — constantes', () {
    test('taux et multiplicateur alignés sur le backend (12 %)', () {
      expect(kDonyCommissionRate, 0.12);
      expect(kDonyCommissionMultiplier, closeTo(1.12, 1e-9));
    });
  });

  group('netToSenderPrice', () {
    test('applique +12 % au net', () {
      expect(netToSenderPrice(10), closeTo(11.20, 1e-9));
      expect(netToSenderPrice(5), closeTo(5.60, 1e-9));
      expect(netToSenderPrice(0), 0);
    });
  });

  group('formatKgPrice', () {
    test('entier si rond, 2 décimales sinon', () {
      expect(formatKgPrice(6), '6');
      expect(formatKgPrice(5.6), '5.60');
      expect(formatKgPrice(8.96), '8.96');
      expect(formatKgPrice(13.44), '13.44');
    });
  });

  group('AnnouncementSenderPricing.senderPricePerKg', () {
    test('utilise le champ backend pricePerKgDisplay quand présent', () {
      // Source de vérité backend : on n\'applique pas un second × 1,12.
      final a = _ann(pricePerKg: 10, pricePerKgDisplay: 11.5);
      expect(a.senderPricePerKg, 11.5);
    });

    test('retombe sur net × 1,12 quand le champ backend est absent', () {
      final a = _ann(pricePerKg: 10);
      expect(a.senderPricePerKg, closeTo(11.20, 1e-9));
    });
  });
}
