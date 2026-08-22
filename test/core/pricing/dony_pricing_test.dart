import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:flutter_test/flutter_test.dart';

AnnouncementModel _ann({
  required double? pricePerKg,
  double? pricePerKgDisplay,
  double? convertedPricePerKg,
  String? convertedCurrency,
  double? pricePerKgDisplayConverted,
}) => AnnouncementModel(
  id: 'a',
  travelerId: 't',
  departureCity: 'Paris',
  arrivalCity: 'Dakar',
  departureDate: DateTime(2026, 7),
  availableKg: 10,
  totalKg: 10,
  pricePerKg: pricePerKg,
  pricePerKgDisplay: pricePerKgDisplay,
  convertedPricePerKg: convertedPricePerKg,
  convertedCurrency: convertedCurrency,
  pricePerKgDisplayConverted: pricePerKgDisplayConverted,
  status: 'OPEN',
  createdAt: DateTime(2026, 6),
  updatedAt: DateTime(2026, 6),
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

  group('formatPriceIn', () {
    test('formate dans la devise donnée, pas toujours en EUR', () {
      final result = formatPriceIn(8, 'CAD');
      expect(result, contains('8'));
      expect(result, contains('CA\$'));
    });

    test('devise EUR : symbole € en suffixe, entier si rond', () {
      final result = formatPriceIn(8, 'EUR');
      expect(result, contains('8'));
      expect(result, contains('€'));
      expect(result, isNot(contains(',00')));
    });

    test('devise absente ou inconnue → repli EUR', () {
      final result = formatPriceIn(8, null);
      expect(result, contains('8'));
      expect(result, contains('€'));
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

    test(
      'null quand ni pricePerKgDisplay ni pricePerKg ne sont exploitables (invité)',
      () {
        // Net masqué pour une session anonyme (pricePerKg absent) et pas de
        // champ display : aucun prix à afficher, jamais un faux 0.
        final a = _ann(pricePerKg: null);
        expect(a.senderPricePerKg, isNull);
      },
    );
  });

  group('AnnouncementSenderPricing.hasKgPrice', () {
    test('vrai avec le net masqué (invité) tant que pricePerKgDisplay > 0', () {
      // Le net est masqué mais pricePerKgDisplay reste toujours servi : le
      // prix au kilo reste exploitable pour l'expéditeur, invité ou non.
      final a = _ann(pricePerKg: null, pricePerKgDisplay: 12.0);
      expect(a.hasKgPrice, isTrue);
      expect(a.senderPricePerKg, 12.0);
    });

    test('faux quand net et display sont tous deux absents (invité, MIXED)', () {
      final a = _ann(pricePerKg: null);
      expect(a.hasKgPrice, isFalse);
    });

    test('faux en mode MIXED sans tarif au kilo (compte inscrit)', () {
      final a = _ann(pricePerKg: 0);
      expect(a.hasKgPrice, isFalse);
    });

    test('vrai avec un net positif et pas de display (ancien payload)', () {
      final a = _ann(pricePerKg: 10);
      expect(a.hasKgPrice, isTrue);
    });
  });

  group('AnnouncementSenderPricing.convertedSenderPricePerKg', () {
    test(
      'majore le net converti par le serveur, comme senderPricePerKg majore le net d\'origine',
      () {
        // Le backend convertit toujours le NET (pricePerKg), jamais le
        // BRUT affiché (senderPricePerKg / pricePerKgDisplay). Avec une
        // commission à 12 %, un net de 10 € converti "brut" (sans
        // majoration) à 6560 XOF ne doit PAS être affiché tel quel à côté
        // d'un prix d'origine qui, lui, est déjà majoré (senderPricePerKg
        // = 11,20 €). L'estimation doit refléter la même majoration :
        // 6560 × 1,12 = 7347,2.
        setDonyCommissionRate(0.12);
        final a = _ann(
          pricePerKg: 10,
          convertedPricePerKg: 6560,
          convertedCurrency: 'XOF',
        );

        expect(a.senderPricePerKg, closeTo(11.2, 1e-9));
        expect(a.convertedSenderPricePerKg, closeTo(7347.2, 1e-6));
        // Preuve explicite que le brut converti diffère du net converti tel
        // quel reçu du serveur (le bug corrigé).
        expect(a.convertedSenderPricePerKg, isNot(closeTo(6560, 1e-6)));
      },
    );

    test(
      'respecte pricePerKgDisplay quand il diverge du net × multiplicateur',
      () {
        // pricePerKgDisplay peut différer légèrement de net × multiplicateur
        // (arrondi backend) : le ratio réellement utilisé doit suivre
        // pricePerKgDisplay, pas recalculer un multiplicateur générique.
        final a = _ann(
          pricePerKg: 10,
          pricePerKgDisplay: 11.5,
          convertedPricePerKg: 6560,
          convertedCurrency: 'XOF',
        );

        // ratio = 11.5 / 10 = 1.15
        expect(a.convertedSenderPricePerKg, closeTo(7544.0, 1e-6));
      },
    );

    test('null quand le serveur n\'a rien converti', () {
      final a = _ann(pricePerKg: 10);
      expect(a.convertedSenderPricePerKg, isNull);
    });

    test('null quand pricePerKg est nul (mode MIXED sans tarif au kilo)', () {
      final a = _ann(
        pricePerKg: 0,
        convertedPricePerKg: 100,
        convertedCurrency: 'USD',
      );
      expect(a.convertedSenderPricePerKg, isNull);
    });

    test(
      'null quand pricePerKg est absent et sans repli backend (ancien payload)',
      () {
        // pricePerKg null (invité) : impossible de reconstituer le ratio
        // net→brut, même si convertedPricePerKg était renseigné (en pratique
        // le backend masque les deux ensemble, cf. commit ff8107c1). Sans
        // pricePerKgDisplayConverted (payload antérieur à la PR #219), rien
        // à afficher.
        final a = _ann(
          pricePerKg: null,
          pricePerKgDisplay: 11.5,
          convertedPricePerKg: 6560,
          convertedCurrency: 'XOF',
        );
        expect(a.convertedSenderPricePerKg, isNull);
      },
    );

    test(
      'retombe sur pricePerKgDisplayConverted quand pricePerKg est absent (invité, PR #219)',
      () {
        // Lecteur anonyme : le net (pricePerKg) est masqué donc aucun ratio
        // net→brut n'est calculable ici. Le serveur sert directement le brut
        // déjà converti dans pricePerKgDisplayConverted : c'est lui qu'il
        // faut afficher, pas null.
        final a = _ann(
          pricePerKg: null,
          pricePerKgDisplayConverted: 7347.2,
        );
        expect(a.convertedSenderPricePerKg, closeTo(7347.2, 1e-6));
      },
    );
  });

  group('parsePriceInput', () {
    test('accepte la virgule decimale francaise', () {
      expect(parsePriceInput('12,50'), 12.5);
    });

    test('accepte le point decimal', () {
      expect(parsePriceInput('12.50'), 12.5);
    });

    test('ignore les espaces autour de la saisie', () {
      expect(parsePriceInput('  8 '), 8);
    });

    test('refuse une saisie vide', () {
      expect(parsePriceInput(''), isNull);
      expect(parsePriceInput('   '), isNull);
    });

    test('refuse une saisie non numerique', () {
      expect(parsePriceInput('abc'), isNull);
    });

    // Zéro et négatif ne sont pas des prix : un article à 0 ne laisserait rien
    // à accepter ou refuser au voyageur.
    test('refuse zero et les montants negatifs', () {
      expect(parsePriceInput('0'), isNull);
      expect(parsePriceInput('0,00'), isNull);
      expect(parsePriceInput('-3'), isNull);
    });
  });
}
