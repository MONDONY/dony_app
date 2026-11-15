import 'package:dony/core/config/boat_price_bounds.dart';
import 'package:dony/core/currency/active_rates.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    resetBoatPriceBoundsForTest();
    ActiveRates.resetForTest();
  });

  test('repli : bornes par défaut tant que rien n\'est chargé', () {
    expect(boatPriceBounds, BoatPriceBounds.defaults);
    expect(boatPriceBoundsListenable.value, BoatPriceBounds.defaults);
    expect(BoatPriceBounds.defaults.hardMinEur, 100);
    expect(BoatPriceBounds.defaults.hardMaxEur, 600);
    expect(BoatPriceBounds.defaults.advisedMinEur, 150);
    expect(BoatPriceBounds.defaults.advisedMaxEur, 400);
    expect(BoatPriceBounds.defaults.referenceEur, 240);
  });

  test('setBoatPriceBounds remplace la dernière valeur connue', () {
    const loaded = BoatPriceBounds(
      hardMinEur: 80,
      hardMaxEur: 700,
      advisedMinEur: 120,
      advisedMaxEur: 450,
      referenceEur: 250,
    );
    setBoatPriceBounds(loaded);
    expect(boatPriceBounds, loaded);
  });

  group('fromJson', () {
    test('lit les cinq bornes', () {
      expect(
        BoatPriceBounds.fromJson(const {
          'hardMinEur': 90,
          'hardMaxEur': 650.5,
          'advisedMinEur': '140',
          'advisedMaxEur': 380,
          'referenceEur': 230,
        }),
        const BoatPriceBounds(
          hardMinEur: 90,
          hardMaxEur: 650.5,
          advisedMinEur: 140,
          advisedMaxEur: 380,
          referenceEur: 230,
        ),
      );
    });

    test('champ absent, illisible ou nul : valeur par défaut', () {
      final bounds = BoatPriceBounds.fromJson(const {
        'hardMinEur': 'abc',
        'hardMaxEur': 0,
        'advisedMinEur': null,
      });
      expect(bounds, BoatPriceBounds.defaults);
    });

    test('bornes incohérentes : valeurs par défaut', () {
      expect(
        BoatPriceBounds.fromJson(const {'hardMinEur': 900, 'hardMaxEur': 600}),
        BoatPriceBounds.defaults,
      );
      expect(
        BoatPriceBounds.fromJson(const {
          'advisedMinEur': 500,
          'advisedMaxEur': 400,
        }),
        BoatPriceBounds.defaults,
      );
    });
  });

  group('inCurrency : taux figés et arrondis du serveur', () {
    test('EUR : bornes telles quelles', () {
      final b = BoatPriceBounds.defaults.inCurrency(SupportedCurrency.eur);
      expect(b.hardMin, 100);
      expect(b.hardMax, 600);
      expect(b.advisedMin, 150);
      expect(b.advisedMax, 400);
      expect(b.reference, 240);
    });

    test('XOF : plancher vers le haut, plafond vers le bas, à l\'unité', () {
      final b = BoatPriceBounds.defaults.inCurrency(SupportedCurrency.xof);
      expect(b.hardMin, 65596);
      expect(b.hardMax, 393574);
      expect(b.advisedMin, 98394);
      expect(b.advisedMax, 262382);
      // Prix habituel arrondi à la centaine : 157 429,68 → 157 400.
      expect(b.reference, 157400);
    });

    test('XAF : même taux que XOF', () {
      final b = BoatPriceBounds.defaults.inCurrency(SupportedCurrency.xaf);
      expect(b.hardMin, 65596);
      expect(b.hardMax, 393574);
    });

    test('USD : au centime, sans dérive flottante', () {
      final b = BoatPriceBounds.defaults.inCurrency(SupportedCurrency.usd);
      expect(b.hardMin, 108);
      expect(b.hardMax, 648);
      expect(b.reference, 259);
    });

    test('taux du jour ignorés : seul le taux figé compte', () {
      ActiveRates.setServerRates({'XOF': 700});
      final b = BoatPriceBounds.defaults.inCurrency(SupportedCurrency.xof);
      expect(b.hardMin, 65596);
      expect(b.hardMax, 393574);
    });

    test('borne décimale : arrondis à l\'unité mineure', () {
      const bounds = BoatPriceBounds(
        hardMinEur: 100.005,
        hardMaxEur: 599.999,
        advisedMinEur: 150,
        advisedMaxEur: 400,
        referenceEur: 240,
      );
      final eur = bounds.inCurrency(SupportedCurrency.eur);
      expect(eur.hardMin, 100.01);
      expect(eur.hardMax, 599.99);
    });
  });

  group('BoatPriceBoundsIn', () {
    final b = BoatPriceBounds.defaults.inCurrency(SupportedCurrency.eur);

    test('borne dure', () {
      expect(b.hardBoundOf(null), isNull);
      expect(b.hardBoundOf(99.99), BoatPriceBound.tooLow);
      expect(b.hardBoundOf(100), isNull);
      expect(b.hardBoundOf(600), isNull);
      expect(b.hardBoundOf(600.01), BoatPriceBound.tooHigh);
    });

    test('zone conseillée, jamais en plus d\'une borne dure', () {
      expect(b.advisedBoundOf(null), isNull);
      expect(b.advisedBoundOf(50), isNull);
      expect(b.advisedBoundOf(149), BoatPriceBound.tooLow);
      expect(b.advisedBoundOf(150), isNull);
      expect(b.advisedBoundOf(400), isNull);
      expect(b.advisedBoundOf(401), BoatPriceBound.tooHigh);
      expect(b.advisedBoundOf(700), isNull);
    });
  });
}
