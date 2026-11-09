import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/features/package_request/data/per_kilo_pricing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PerKiloPricing.totalFor', () {
    test('poids × prix au kilo', () {
      expect(
        PerKiloPricing.totalFor(
          weightKg: 4,
          perKilo: 5,
          currency: SupportedCurrency.eur,
        ),
        20,
      );
    });

    test('arrondi au centime en euro', () {
      expect(
        PerKiloPricing.totalFor(
          weightKg: 3,
          perKilo: 3.335,
          currency: SupportedCurrency.eur,
        ),
        10.01,
      );
      expect(
        PerKiloPricing.totalFor(
          weightKg: 2.5,
          perKilo: 1.11,
          currency: SupportedCurrency.eur,
        ),
        2.78,
      );
    });

    test('arrondi au franc en CFA (pas de sous-unité)', () {
      expect(
        PerKiloPricing.totalFor(
          weightKg: 1.5,
          perKilo: 333,
          currency: SupportedCurrency.xof,
        ),
        500,
      );
      expect(
        PerKiloPricing.totalFor(
          weightKg: 2.5,
          perKilo: 1000,
          currency: SupportedCurrency.xaf,
        ),
        2500,
      );
    });

    test('poids inconnu, nul ou négatif : pas de total', () {
      for (final w in <double?>[null, 0, -1]) {
        expect(
          PerKiloPricing.totalFor(
            weightKg: w,
            perKilo: 5,
            currency: SupportedCurrency.eur,
          ),
          isNull,
        );
        expect(PerKiloPricing.isAvailable(w), isFalse);
      }
      expect(PerKiloPricing.isAvailable(0.5), isTrue);
    });

    test('prix au kilo absent ou non positif : pas de total', () {
      for (final v in <double?>[null, 0, -2]) {
        expect(
          PerKiloPricing.totalFor(
            weightKg: 4,
            perKilo: v,
            currency: SupportedCurrency.eur,
          ),
          isNull,
        );
      }
    });
  });

  group('PerKiloPricing.perKiloFor', () {
    test('total exact : le prix au kilo qui le redonne', () {
      expect(
        PerKiloPricing.perKiloFor(
          total: 20,
          weightKg: 4,
          currency: SupportedCurrency.eur,
        ),
        5,
      );
      expect(
        PerKiloPricing.perKiloFor(
          total: 21,
          weightKg: 4,
          currency: SupportedCurrency.eur,
        ),
        5.25,
      );
    });

    test(
      'total non convertible exactement : null, jamais un total modifié',
      () {
        expect(
          PerKiloPricing.perKiloFor(
            total: 10,
            weightKg: 3,
            currency: SupportedCurrency.eur,
          ),
          isNull,
        );
      },
    );

    test('total ou poids manquant : null', () {
      expect(
        PerKiloPricing.perKiloFor(
          total: null,
          weightKg: 4,
          currency: SupportedCurrency.eur,
        ),
        isNull,
      );
      expect(
        PerKiloPricing.perKiloFor(
          total: 20,
          weightKg: null,
          currency: SupportedCurrency.eur,
        ),
        isNull,
      );
    });
  });
}
