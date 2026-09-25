import 'package:dony/features/disputes/presentation/utils/dispute_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  test('disputeTypeLabel traduit les types delivery no-show', () {
    expect(
      disputeTypeLabel(fr, 'RECIPIENT_NO_SHOW_CONTESTED'),
      'Absence du destinataire',
    );
    expect(
      disputeTypeLabel(fr, 'RECIPIENT_NO_SHOW'),
      'Absence du destinataire',
    );
    expect(
      disputeTypeLabel(fr, 'TRAVELER_DELIVERY_NO_SHOW_CONTESTED'),
      'Défaut de livraison',
    );
    expect(
      disputeTypeLabel(fr, 'TRAVELER_DELIVERY_NO_SHOW'),
      'Défaut de livraison',
    );
  });

  test(
    'disputeTypeLabel garde le comportement existant (contestation d\'absence + fallback)',
    () {
      expect(
        disputeTypeLabel(fr, 'SENDER_NO_SHOW_CONTESTED'),
        "Contestation d'absence",
      );
      expect(disputeTypeLabel(fr, 'UNKNOWN_TYPE'), 'UNKNOWN_TYPE');
    },
  );

  test('disputeStatusLabel traduit les statuts connus + fallback', () {
    expect(disputeStatusLabel(fr, 'OPEN'), 'En instruction');
    expect(disputeStatusLabel(fr, 'RESOLVED'), 'Résolu');
    expect(disputeStatusLabel(fr, 'UNKNOWN_STATUS'), 'UNKNOWN_STATUS');
  });

  test(
    'disputeOtherParty : Voyageur pour le rôle SENDER, Expéditeur sinon',
    () {
      expect(fr.disputeOtherParty('SENDER', 'Awa K.'), 'Voyageur : Awa K.');
      expect(fr.disputeOtherParty('TRAVELER', 'Awa K.'), 'Expéditeur : Awa K.');
    },
  );

  test('disputeWeightLabel : entier sans décimale, formatOneDecimal sinon', () {
    expect(disputeWeightLabel(fr, 5), '5');
    expect(disputeWeightLabel(fr, 4.5), '4,5');
    expect(disputeWeightLabel(en, 4.5), '4.5');
  });

  test('anglais : types, statuts et autre partie', () {
    expect(disputeTypeLabel(en, 'RECIPIENT_NO_SHOW'), 'Recipient no-show');
    expect(
      disputeTypeLabel(en, 'TRAVELER_DELIVERY_NO_SHOW'),
      'Delivery failure',
    );
    expect(disputeTypeLabel(en, 'SENDER_NO_SHOW_CONTESTED'), 'No-show contest');
    expect(disputeStatusLabel(en, 'OPEN'), 'Under review');
    expect(disputeStatusLabel(en, 'RESOLVED'), 'Resolved');
    expect(en.disputeOtherParty('SENDER', 'Awa K.'), 'Traveler: Awa K.');
    expect(en.disputeOtherParty('TRAVELER', 'Awa K.'), 'Sender: Awa K.');
  });
}
