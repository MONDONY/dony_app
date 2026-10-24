import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/error/error_catalog.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/l10n_test_helpers.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('textes de la modification d\'un colis', () {
    test('bouton carte : « Bloquer {amount} et envoyer »', () {
      expect(fr.amendmentSubmitCard('12,00 €'), 'Bloquer 12,00 € et envoyer');
      expect(en.amendmentSubmitCard('€12.00'), 'Block €12.00 and send');
    });

    test('moyens de paiement', () {
      expect(fr.amendmentRailCard, 'Carte');
      expect(fr.amendmentRailMobileMoney, 'Mobile money');
      expect(fr.amendmentRailCash, 'Espèces');
      expect(en.amendmentRailCard, 'Card');
      expect(en.amendmentRailMobileMoney, 'Mobile money');
      expect(en.amendmentRailCash, 'Cash');
    });

    test('envoi et réponse du voyageur', () {
      expect(fr.amendmentSubmit('Moussa'), 'Envoyer la demande à Moussa');
      expect(en.amendmentSubmit('Moussa'), 'Send the request to Moussa');
      expect(fr.amendmentAccept('+23,50 €'), 'Accepter (+23,50 €)');
      expect(en.amendmentAccept('+€23.50'), 'Accept (+€23.50)');
      expect(fr.amendmentDecline, 'Refuser');
      expect(en.amendmentDecline, 'Decline');
    });
  });

  group('messages d\'erreur de la modification', () {
    const codes = [
      'amendment-disabled',
      'amendment-not-eligible',
      'amendment-already-open',
      'amendment-limit-reached',
      'amendment-rail-unavailable',
      'amendment-amount-out-of-range',
      'amendment-capacity-unavailable',
      'amendment-empty',
      'amendment-item-unknown',
      'amendment-expired',
      'amendment-payment-in-progress',
      'amendment-capture-failed',
      'amendment-commission-unfunded',
      'amendment-not-found',
      'handover-amendment-pending',
    ];
    String message(String code, Locale lang) => ErrorCatalog.lookup(
      ConflictException('d', code: code),
      l10n: lookupAppLocalizations(lang),
    ).message;

    test('chaque code a un message FR et EN distincts', () {
      for (final code in codes) {
        final f = message(code, AppL10n.fr);
        final e = message(code, AppL10n.en);
        expect(f, isNotEmpty, reason: code);
        expect(e, isNotEmpty, reason: code);
        expect(e, isNot(f), reason: code);
      }
    });

    test('solde insuffisant pour la commission', () {
      expect(
        message('amendment-commission-unfunded', AppL10n.fr),
        'Votre solde ne couvre pas la commission Yadony de cette '
        'modification. Rechargez-le pour accepter.',
      );
      expect(
        message('amendment-commission-unfunded', AppL10n.en),
        "Your balance doesn't cover the Yadony commission for this edit. "
        'Top it up to accept.',
      );
    });

    test('paiement non encaissé', () {
      expect(
        message('amendment-capture-failed', AppL10n.fr),
        "Le paiement n'a pas pu être encaissé. Rien n'est débité, la demande "
        'est annulée.',
      );
      expect(
        message('amendment-capture-failed', AppL10n.en),
        "The payment couldn't be collected. Nothing was charged and the "
        'request is cancelled.',
      );
    });

    test('scan de remise bloqué', () {
      expect(
        message('handover-amendment-pending', AppL10n.fr),
        "Une modification du colis attend la réponse du voyageur. Scannez le "
        "colis une fois qu'il a répondu.",
      );
      expect(
        message('handover-amendment-pending', AppL10n.en),
        "An edit to the parcel is awaiting the traveler's reply. Scan the "
        "parcel once they've replied.",
      );
    });
  });
}
