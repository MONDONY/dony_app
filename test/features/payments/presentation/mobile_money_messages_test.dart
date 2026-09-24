// Messages composés (jamais assemblés à la main) du paiement mobile money :
// bandeau « aucun réseau commun » (joinList à 1, 2 et 3 réseaux), variantes
// du texte PIN opérateur, et les deux délais dépassés (bid / négociation).
// Ces messages sont partagés par mobile_money_account_screen.dart et
// mobile_money_awaiting_screen.dart (voir leurs tests de widget respectifs
// pour le rendu à l'écran).

import 'package:dony/core/currency/country_catalog.dart';
import 'package:dony/l10n/country_names.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group(
    'countryName vs CountryCatalog pour les pays mobile money '
    '(mobile_money_account_screen.dart et mobile_money_awaiting_screen.dart)',
    () {
      // SN, CI, ML, BF, BJ, TG, NE, CM, GA, CG sont au catalogue : countryName
      // doit rendre exactement le même nom que CountryCatalog.byCode(...).name,
      // sinon le français affiché changerait par rapport à l'ancien
      // `CountryCatalog.byCode(code)?.name ?? code`.
      for (final code in [
        'SN',
        'CI',
        'ML',
        'BF',
        'BJ',
        'TG',
        'NE',
        'CM',
        'GA',
        'CG',
      ]) {
        test(
          '$code : countryName(fr, ...) == CountryCatalog.byCode(...).name',
          () {
            expect(countryName(fr, code), CountryCatalog.byCode(code)!.name);
          },
        );
      }

      // CD et GN sont hors catalogue (CountryCatalog.byCode renvoie null) :
      // l'ancien repli `CountryCatalog.byCode(code)?.name ?? code` affichait
      // déjà le code brut pour ces deux-là. Le helper des écrans mobile money
      // (`_countryName`/`_country`) reproduit ce repli en n'appelant
      // `countryName` que si `CountryCatalog.byCode(code)` est non nul :
      // countryName(fr, 'CD') traduit bien « CD » (countryNameCd existe dans
      // le catalogue de noms), mais ce cas n'est jamais atteint pour CD/GN
      // dans ces deux écrans, qui gardent le code brut, comme avant.
      test(
        'CD et GN : hors CountryCatalog, repli sur le code brut conservé',
        () {
          expect(CountryCatalog.byCode('CD'), isNull);
          expect(CountryCatalog.byCode('GN'), isNull);
        },
      );
    },
  );

  group('mobileMoneyNoCommonNetwork (joinList)', () {
    test('un seul réseau : fr et en', () {
      expect(
        fr.mobileMoneyNoCommonNetwork('Aminata', 'Wave', 'Sénégal'),
        "Aminata accepte Wave, qui n'existent pas pour ton numéro "
        '(Sénégal). Change de numéro payeur ou écris-lui depuis la '
        'conversation.',
      );
      expect(
        en.mobileMoneyNoCommonNetwork('Aminata', 'Wave', 'Senegal'),
        "Aminata accepts Wave, which aren't available for your number "
        '(Senegal). Change the paying number or message them from the '
        'conversation.',
      );
    });

    test('deux réseaux : fr « et », en « and », comme l\'ancien texte', () {
      expect(
        fr.mobileMoneyNoCommonNetwork(
          'Aminata',
          'Wave et Orange Money',
          'Bénin',
        ),
        "Aminata accepte Wave et Orange Money, qui n'existent pas pour "
        'ton numéro (Bénin). Change de numéro payeur ou écris-lui depuis '
        'la conversation.',
      );
      expect(
        en.mobileMoneyNoCommonNetwork(
          'Aminata',
          'Wave and Orange Money',
          'Benin',
        ),
        "Aminata accepts Wave and Orange Money, which aren't available "
        'for your number (Benin). Change the paying number or message '
        'them from the conversation.',
      );
    });

    test('trois réseaux : fr « Wave, Orange Money et MTN » (égal à l\'ancien '
        'texte concaténé), en « Wave, Orange Money, and MTN »', () {
      expect(
        fr.mobileMoneyNoCommonNetwork(
          'Aminata',
          'Wave, Orange Money et MTN',
          'Côte d\'Ivoire',
        ),
        "Aminata accepte Wave, Orange Money et MTN, qui n'existent pas "
        "pour ton numéro (Côte d'Ivoire). Change de numéro payeur ou "
        'écris-lui depuis la conversation.',
      );
      expect(
        en.mobileMoneyNoCommonNetwork(
          'Aminata',
          'Wave, Orange Money, and MTN',
          "Cote d'Ivoire",
        ),
        "Aminata accepts Wave, Orange Money, and MTN, which aren't "
        "available for your number (Cote d'Ivoire). Change the paying "
        'number or message them from the conversation.',
      );
    });
  });

  group('joinList (composition du paramètre {networks})', () {
    test('un réseau : inchangé', () {
      expect(joinList(fr, ['Wave']), 'Wave');
      expect(joinList(en, ['Wave']), 'Wave');
    });

    test('deux réseaux : « et » en fr, « and » en en', () {
      expect(joinList(fr, ['Wave', 'Orange Money']), 'Wave et Orange Money');
      expect(joinList(en, ['Wave', 'Orange Money']), 'Wave and Orange Money');
    });

    test(
      'trois réseaux : fr « Wave, Orange Money et MTN » (égal à l\'ancien '
      '_joinLabels), en avec virgule oxford « Wave, Orange Money, and MTN »',
      () {
        expect(
          joinList(fr, ['Wave', 'Orange Money', 'MTN']),
          'Wave, Orange Money et MTN',
        );
        expect(
          joinList(en, ['Wave', 'Orange Money', 'MTN']),
          'Wave, Orange Money, and MTN',
        );
      },
    );
  });

  group('mobileMoneyAcceptsAndReceives', () {
    test('fr et en, avec des réseaux déjà joints', () {
      expect(
        fr.mobileMoneyAcceptsAndReceives('Aminata', 'Wave et Orange Money'),
        'Aminata accepte Wave et Orange Money, et reçoit sur le réseau '
        'que tu choisis.',
      );
      expect(
        en.mobileMoneyAcceptsAndReceives('Aminata', 'Wave and Orange Money'),
        'Aminata accepts Wave and Orange Money and receives on the '
        'network you choose.',
      );
    });
  });

  group('code PIN opérateur (deux variantes)', () {
    test('opérateur connu : le nom est inséré, fr et en', () {
      expect(
        fr.mobileMoneyPinSent('Orange Money'),
        'Valide le paiement sur ton téléphone : une demande de code PIN '
        "vient de t'être envoyée par Orange Money.",
      );
      expect(
        en.mobileMoneyPinSent('Orange Money'),
        'Approve the payment on your phone: Orange Money just sent you a '
        'PIN request.',
      );
    });

    test('opérateur inconnu : repli générique, fr et en', () {
      expect(
        fr.mobileMoneyPinSentUnknownProvider,
        'Valide le paiement sur ton téléphone : une demande de code PIN '
        "vient de t'être envoyée par ton opérateur.",
      );
      expect(
        en.mobileMoneyPinSentUnknownProvider,
        'Approve the payment on your phone: your mobile operator just '
        'sent you a PIN request.',
      );
    });
  });

  group('délai dépassé (deux portées)', () {
    test('portée bid : demande annulée, fr et en', () {
      expect(
        fr.mobileMoneyExpiredBid,
        'Délai dépassé. La demande a été annulée, refais une offre au '
        'voyageur.',
      );
      expect(
        en.mobileMoneyExpiredBid,
        "Time's up. The request was canceled. Make a new offer to the "
        'traveler.',
      );
    });

    test('portée négociation : retour à « à payer », fr et en', () {
      expect(
        fr.mobileMoneyExpiredNegotiation,
        'Délai dépassé. Le fil est revenu à « à payer » : tu peux '
        'relancer le paiement ou changer de moyen de paiement depuis le '
        'fil.',
      );
      expect(
        en.mobileMoneyExpiredNegotiation,
        "Time's up. The thread is back to \"to pay\": you can retry the "
        'payment or change the payment method from the thread.',
      );
    });
  });
}
