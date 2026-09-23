import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/presentation/package_request_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('PaymentMethodL10n.label', () {
    test('fr', () {
      expect(PaymentMethod.stripe.label(fr), 'Carte');
      expect(PaymentMethod.cash.label(fr), 'Espèces');
      expect(PaymentMethod.mobileMoney.label(fr), 'Mobile money');
      expect(PaymentMethod.wave.label(fr), 'Wave');
      expect(PaymentMethod.orangeMoney.label(fr), 'Orange Money');
    });

    test('en', () {
      expect(PaymentMethod.stripe.label(en), 'Card');
      expect(PaymentMethod.cash.label(en), 'Cash');
      expect(PaymentMethod.mobileMoney.label(en), 'Mobile money');
      expect(PaymentMethod.wave.label(en), 'Wave');
      expect(PaymentMethod.orangeMoney.label(en), 'Orange Money');
    });
  });

  group('threadPriceLabel', () {
    // Épingle le taux de commission : ces tests assertent des montants
    // calculés à 12 % (indépendants du défaut kDonyCommissionRateDefault).
    setUpAll(() => setDonyCommissionRate(0.12));
    tearDownAll(() => setDonyCommissionRate(kDonyCommissionRateDefault));

    test('voyageur : voit son net (fr)', () {
      expect(threadPriceLabel(fr, 35, 39.20, true), 'Tu reçois 35,00 €');
    });

    test('voyageur : voit son net (en) — le montant EUR garde le format '
        'fr_FR de la devise, seul le texte change', () {
      expect(threadPriceLabel(en, 35, 39.20, true), 'You receive 35,00 €');
    });

    test('expéditeur : voit le brut fourni (fr)', () {
      expect(threadPriceLabel(fr, 35, 39.20, false), 'Tu paies 39,20 €');
    });

    test('expéditeur : voit le brut fourni (en)', () {
      expect(threadPriceLabel(en, 35, 39.20, false), 'You pay 39,20 €');
    });

    test('expéditeur sans gross : calcule depuis le net (fr)', () {
      expect(threadPriceLabel(fr, 35, null, false), 'Tu paies 39,20 €');
    });

    test('expéditeur sans gross : calcule depuis le net (en)', () {
      expect(threadPriceLabel(en, 35, null, false), 'You pay 39,20 €');
    });

    test('le voyageur ignore le brut fourni (fr)', () {
      expect(threadPriceLabel(fr, 50, 60.0, true), 'Tu reçois 50,00 €');
    });

    test('le voyageur ignore le brut fourni (en)', () {
      expect(threadPriceLabel(en, 50, 60.0, true), 'You receive 50,00 €');
    });

    test('expéditeur sans gross : net*1.12 arrondi à 2 décimales (fr) — '
        '100 → 112,00', () {
      expect(threadPriceLabel(fr, 100, null, false), 'Tu paies 112,00 €');
    });

    test('expéditeur sans gross : net*1.12 arrondi à 2 décimales (en) — '
        '100 → 112,00', () {
      expect(threadPriceLabel(en, 100, null, false), 'You pay 112,00 €');
    });
  });

  group('weightRangeLabel', () {
    test('fr', () {
      expect(weightRangeLabel(fr), 'Entre 0,5 et 32 kg');
    });

    test('en', () {
      expect(weightRangeLabel(en), 'Between 0.5 and 32 kg');
    });
  });

  group('senderFallbackName', () {
    test('fr', () {
      expect(senderFallbackName(fr), 'Utilisateur Yadony');
    });

    test('en', () {
      expect(senderFallbackName(en), 'Yadony user');
    });
  });
}
