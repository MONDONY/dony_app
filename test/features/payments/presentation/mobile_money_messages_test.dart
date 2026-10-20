// Messages composés (jamais assemblés à la main) du paiement mobile money :
// liste des réseaux acceptés (joinList à 1, 2 et 3 réseaux), libellés de
// l'écran « Payer le colis », et les délais dépassés (bid / négociation).
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
        'que vous choisissez.',
      );
      expect(
        en.mobileMoneyAcceptsAndReceives('Aminata', 'Wave and Orange Money'),
        'Aminata accepts Wave and Orange Money and receives on the '
        'network you choose.',
      );
    });
  });

  group('écran Payer le colis (libellés)', () {
    test('titres : colis et supplément, fr et en', () {
      expect(fr.mobileMoneyPayParcelTitle, 'Payer le colis');
      expect(en.mobileMoneyPayParcelTitle, 'Pay for the parcel');
      expect(fr.mobileMoneyPaySupplementTitle, 'Payer le supplément');
      expect(en.mobileMoneyPaySupplementTitle, 'Pay the extra charge');
    });

    test('récapitulatif : versement au voyageur à la livraison', () {
      expect(fr.mobileMoneyPaidToTravelerLabel, 'Versé au voyageur');
      expect(fr.mobileMoneyPaidToTravelerValue, 'À la livraison');
      expect(en.mobileMoneyPaidToTravelerLabel, 'Paid to the traveler');
      expect(en.mobileMoneyPaidToTravelerValue, 'On delivery');
    });

    test('échec : titre dédié, fr et en', () {
      expect(fr.mobileMoneyPaymentFailedTitle, 'Paiement non abouti');
      expect(en.mobileMoneyPaymentFailedTitle, 'Payment not completed');
    });

    test('pas encore validé : le paiement peut encore aboutir, jamais '
        '« délai dépassé »', () {
      expect(
        fr.mobileMoneyOverdueBody,
        'Si vous validez quand même dans les prochaines minutes, votre '
        'paiement sera pris en compte.',
      );
      expect(
        en.mobileMoneyOverdueBody,
        'If you still approve within the next few minutes, your payment '
        'will go through.',
      );
      expect(fr.mobileMoneyOverdueBody, isNot(contains('dépassé')));
      expect(en.mobileMoneyOverdueBody, isNot(contains("Time's up")));
    });
  });

  group('délai dépassé (deux portées)', () {
    test('portée bid : demande annulée, fr et en', () {
      expect(
        fr.mobileMoneyExpiredBid,
        'Délai dépassé. La demande a été annulée, refaites une offre au '
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
        'Délai dépassé. Le fil est revenu à « à payer » : vous pouvez '
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
