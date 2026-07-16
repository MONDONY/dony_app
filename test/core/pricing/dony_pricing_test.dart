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
  // Le taux est un état module-level ajustable : on remet le défaut après chaque
  // test pour éviter toute pollution entre tests.
  tearDown(() => setDonyCommissionRate(kDonyCommissionRateDefault));

  group('dony_pricing — défaut', () {
    test('taux et multiplicateur par défaut alignés sur le backend (5 %)', () {
      expect(donyCommissionRate, 0.05);
      expect(donyCommissionMultiplier, closeTo(1.05, 1e-9));
    });
  });

  group('donyCommissionPercentLabel', () {
    test('taux par défaut → entier sans décimale', () {
      expect(donyCommissionPercentLabel, '5');
    });

    test('taux entier → entier sans décimale', () {
      setDonyCommissionRate(0.12);
      expect(donyCommissionPercentLabel, '12');
    });

    test('taux décimal → 1 décimale avec virgule française', () {
      setDonyCommissionRate(0.125);
      expect(donyCommissionPercentLabel, '12,5');
    });
  });

  group('setDonyCommissionRate (source unique ajustable)', () {
    test('met à jour taux, multiplicateur et conversion', () {
      setDonyCommissionRate(0.20);
      expect(donyCommissionRate, 0.20);
      expect(donyCommissionMultiplier, closeTo(1.20, 1e-9));
      expect(netToSenderPrice(10), closeTo(12.0, 1e-9));
    });

    test('ignore les valeurs aberrantes (reste sur le repli)', () {
      setDonyCommissionRate(1.5);
      expect(donyCommissionRate, kDonyCommissionRateDefault);
      setDonyCommissionRate(-0.1);
      expect(donyCommissionRate, kDonyCommissionRateDefault);
    });
  });

  group('netToSenderPrice', () {
    test('applique +5 % au net', () {
      expect(netToSenderPrice(10), closeTo(10.50, 1e-9));
      expect(netToSenderPrice(5), closeTo(5.25, 1e-9));
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
      // Source de vérité backend : on n\'applique pas un second multiplicateur.
      final a = _ann(pricePerKg: 10, pricePerKgDisplay: 11.5);
      expect(a.senderPricePerKg, 11.5);
    });

    test('retombe sur net × 1,05 quand le champ backend est absent', () {
      final a = _ann(pricePerKg: 10);
      expect(a.senderPricePerKg, closeTo(10.50, 1e-9));
    });
  });
}
