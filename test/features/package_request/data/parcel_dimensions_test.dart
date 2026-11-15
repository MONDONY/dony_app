import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/features/package_request/data/parcel_dimensions.dart';
import 'package:dony/features/package_request/data/per_m3_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParcelDimensions.volumeM3 (parité avec ParcelFitRules.volumeM3)', () {
    test('L × l × h / 1 000 000', () {
      expect(ParcelDimensions.volumeM3(100, 100, 100), 1.0);
      expect(ParcelDimensions.volumeM3(50, 40, 50), 0.1);
      expect(ParcelDimensions.volumeM3(400, 400, 400), 64.0);
    });

    test('trois décimales, demi vers le haut', () {
      expect(ParcelDimensions.volumeM3(30, 30, 30), 0.027);
      // 12 167 cm³ → 0,012 ; 12 500 cm³ → 0,013 (demi vers le haut).
      expect(ParcelDimensions.volumeM3(25, 25, 20), 0.013);
      expect(ParcelDimensions.volumeM3(23, 23, 23), 0.012);
    });

    test('minimum 0,001 : 1 × 1 × 1 cm', () {
      expect(ParcelDimensions.volumeM3(1, 1, 1), 0.001);
    });

    test('null si une dimension manque ou sort des bornes', () {
      expect(ParcelDimensions.volumeM3(null, 10, 10), isNull);
      expect(ParcelDimensions.volumeM3(10, null, 10), isNull);
      expect(ParcelDimensions.volumeM3(10, 10, null), isNull);
      expect(ParcelDimensions.volumeM3(0, 10, 10), isNull);
      expect(ParcelDimensions.volumeM3(10, 401, 10), isNull);
    });
  });

  group('ParcelDimensions : bornes et règles par mode', () {
    test('bornes 1 à 400 cm', () {
      expect(ParcelDimensions.isValidCm(0), isFalse);
      expect(ParcelDimensions.isValidCm(1), isTrue);
      expect(ParcelDimensions.isValidCm(400), isTrue);
      expect(ParcelDimensions.isValidCm(401), isFalse);
      expect(ParcelDimensions.isValidCm(null), isFalse);
      expect(ParcelDimensions.areValid(1, 2, 3), isTrue);
      expect(ParcelDimensions.areValid(1, 2, null), isFalse);
    });

    test('obligatoires en bateau seulement', () {
      expect(ParcelDimensions.isRequiredFor(TransportMode.boat), isTrue);
      expect(ParcelDimensions.isRequiredFor(null), isFalse);
      expect(ParcelDimensions.isRequiredFor(TransportMode.plane), isFalse);
      expect(ParcelDimensions.isRequiredFor(TransportMode.car), isFalse);
    });

    test('gardées en bateau et « peu importe », jamais en avion ni route', () {
      expect(ParcelDimensions.isKeptFor(TransportMode.boat), isTrue);
      expect(ParcelDimensions.isKeptFor(null), isTrue);
      expect(ParcelDimensions.isKeptFor(TransportMode.plane), isFalse);
      expect(ParcelDimensions.isKeptFor(TransportMode.car), isFalse);
      expect(ParcelDimensions.isKeptFor(TransportMode.bus), isFalse);
    });
  });

  group('PerM3Pricing', () {
    test('0,1 m³ × 600 € = 60 €', () {
      expect(
        PerM3Pricing.totalFor(
          volumeM3: 0.1,
          perM3: 600,
          currency: SupportedCurrency.eur,
        ),
        60,
      );
    });

    test('arrondi à la précision de la devise (euro, franc CFA)', () {
      expect(
        PerM3Pricing.totalFor(
          volumeM3: 0.027,
          perM3: 333.33,
          currency: SupportedCurrency.eur,
        ),
        9.0,
      );
      expect(
        PerM3Pricing.totalFor(
          volumeM3: 0.027,
          perM3: 100000,
          currency: SupportedCurrency.xof,
        ),
        2700,
      );
    });

    test('rien sans volume ni prix positif', () {
      for (final (v, p) in [(null, 5.0), (0.0, 5.0), (0.1, null), (0.1, 0.0)]) {
        expect(
          PerM3Pricing.totalFor(
            volumeM3: v,
            perM3: p,
            currency: SupportedCurrency.eur,
          ),
          isNull,
        );
      }
      expect(PerM3Pricing.isAvailable(null), isFalse);
      expect(PerM3Pricing.isAvailable(0.001), isTrue);
    });

    test('perM3For : prix qui redonne exactement le total, sinon null', () {
      expect(
        PerM3Pricing.perM3For(
          total: 60,
          volumeM3: 0.1,
          currency: SupportedCurrency.eur,
        ),
        600,
      );
      expect(
        PerM3Pricing.perM3For(
          total: 0.01,
          volumeM3: 3,
          currency: SupportedCurrency.eur,
        ),
        isNull,
      );
      expect(
        PerM3Pricing.perM3For(
          total: null,
          volumeM3: 0.1,
          currency: SupportedCurrency.eur,
        ),
        isNull,
      );
    });
  });
}
