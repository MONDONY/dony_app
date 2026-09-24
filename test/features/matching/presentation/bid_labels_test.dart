import 'package:dony/features/matching/bloc/bid_acceptance_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/presentation/bid_labels.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

BidNegotiationSummary _summary({String status = 'NEGOTIATING', String? role}) =>
    BidNegotiationSummary(
      bidId: 'bid-1',
      announcementId: 'ann-1',
      status: status,
      role: role,
    );

BidModel _bid({String? senderName}) => BidModel(
  id: 'b1',
  announcementId: 'a1',
  senderId: 's1',
  senderName: senderName,
  weightKg: 5.0,
  description: 'Test',
  status: 'PENDING',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

void main() {
  final l = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  group('BidNegotiationStageL10n.stageLabel', () {
    // Note : le getter supprimé (`BidNegotiationSummary.stageLabel`) vivait
    // déjà sur `BidNegotiationSummary` (la carte de la liste des discussions),
    // pas sur `BidNegotiation` (le fil complet) — la fiche de tâche nommait le
    // premier type par erreur. L'extension suit le code réel.
    test('accord carte, vue expéditeur : à payer', () {
      expect(_summary(status: 'AWAITING_PAYMENT').stageLabel(l), 'à payer');
      expect(_summary(status: 'AWAITING_PAYMENT').stageLabel(en), 'to pay');
    });

    test('accord carte, vue voyageur : attente paiement', () {
      expect(
        _summary(status: 'AWAITING_PAYMENT', role: 'TRAVELER').stageLabel(l),
        'attente paiement',
      );
      expect(
        _summary(status: 'AWAITING_PAYMENT', role: 'TRAVELER').stageLabel(en),
        'awaiting payment',
      );
    });

    test('accord en espèces : accord conclu', () {
      expect(_summary(status: 'PENDING').stageLabel(l), 'accord conclu');
      expect(_summary(status: 'PENDING').stageLabel(en), 'deal agreed');
    });

    test('fil clos : terminé', () {
      expect(_summary(status: 'ACCEPTED').stageLabel(l), 'terminé');
      expect(_summary(status: 'ACCEPTED').stageLabel(en), 'closed');
    });

    test('négociation en cours : proposition', () {
      expect(_summary().stageLabel(l), 'proposition');
      expect(_summary().stageLabel(en), 'proposal');
    });
  });

  group('BidSenderName.senderDisplayName', () {
    test('retourne le nom quand il est présent', () {
      expect(
        _bid(senderName: 'Amadou Diallo').senderDisplayName(l),
        'Amadou Diallo',
      );
      expect(
        _bid(senderName: 'Amadou Diallo').senderDisplayName(en),
        'Amadou Diallo',
      );
    });

    test('repli traduit quand le nom est absent', () {
      expect(_bid().senderDisplayName(l), 'Expéditeur');
      expect(_bid().senderDisplayName(en), 'Sender');
    });

    test('repli traduit quand le nom est vide', () {
      expect(_bid(senderName: '').senderDisplayName(l), 'Expéditeur');
      expect(_bid(senderName: '').senderDisplayName(en), 'Sender');
    });
  });

  group('travelerTripsCount', () {
    test('singulier et pluriel en français', () {
      expect(travelerTripsCount(l, 1), '1 trajet');
      expect(travelerTripsCount(l, 3), '3 trajets');
    });

    test('singulier et pluriel en anglais', () {
      expect(travelerTripsCount(en, 1), '1 trip');
      expect(travelerTripsCount(en, 3), '3 trips');
    });
  });

  group('senderShipmentsCount', () {
    test('singulier et pluriel en français', () {
      expect(senderShipmentsCount(l, 1), '1 envoi');
      expect(senderShipmentsCount(l, 4), '4 envois');
    });

    test('singulier et pluriel en anglais', () {
      expect(senderShipmentsCount(en, 1), '1 shipment');
      expect(senderShipmentsCount(en, 4), '4 shipments');
    });
  });

  group('BidFailedDisplay.displayMessage', () {
    test('serverMessage non vide prime sur la raison', () {
      final state = BidFailed(
        serverMessage: 'Carte refusée',
        reason: BidFailureReason.refused,
      );
      expect(state.displayMessage(l), 'Carte refusée');
      expect(state.displayMessage(en), 'Carte refusée');
    });

    test('serverMessage composé uniquement d\'espaces est ignoré', () {
      final state = BidFailed(
        serverMessage: '   ',
        reason: BidFailureReason.refused,
      );
      expect(state.displayMessage(l), 'Acceptation refusée');
      expect(state.displayMessage(en), 'Acceptance declined');
    });

    test('serverMessage vide donne la clé de la raison', () {
      final state = BidFailed(
        serverMessage: '',
        reason: BidFailureReason.confirmFailed,
      );
      expect(state.displayMessage(l), 'Confirmation échouée');
      expect(state.displayMessage(en), 'Confirmation failed');
    });

    test('serverMessage null : clé confirmFailed', () {
      final state = BidFailed(reason: BidFailureReason.confirmFailed);
      expect(state.displayMessage(l), 'Confirmation échouée');
      expect(state.displayMessage(en), 'Confirmation failed');
    });

    test('serverMessage null : clé bankAuthInterrupted', () {
      final state = BidFailed(reason: BidFailureReason.bankAuthInterrupted);
      expect(state.displayMessage(l), 'Authentification bancaire interrompue');
      expect(
        state.displayMessage(en),
        'Bank authentication was interrupted',
      );
    });

    test('serverMessage null : clé refused', () {
      final state = BidFailed(reason: BidFailureReason.refused);
      expect(state.displayMessage(l), 'Acceptation refusée');
      expect(state.displayMessage(en), 'Acceptance declined');
    });
  });
}
