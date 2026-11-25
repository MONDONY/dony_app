import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/parcel_step_moment.dart';
import 'package:dony/features/video_modal/data/models/parcel_role.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:flutter_test/flutter_test.dart';

/// Moment d'étape du colis vu depuis la fiche colis : étape selon le statut,
/// rôle du lecteur, variables des textes, boutons possibles.
void main() {
  const sender = 'sender-1';
  const traveler = 'traveler-1';

  BidModel bid({
    String status = 'ARRIVED',
    String? travelerId = traveler,
    bool recipientIsSender = false,
    String? confirmationCode = '482913',
    String? trackingToken = 'tok',
    String? recipientName = 'Awa Diop',
    String? travelerName = 'Moussa',
    String? senderName = 'Fatou',
    String? arrivalCity = 'Dakar',
  }) => BidModel(
    id: 'bid-1',
    announcementId: 'ann-1',
    senderId: sender,
    travelerId: travelerId,
    status: status,
    createdAt: DateTime(2026, 11),
    updatedAt: DateTime(2026, 11),
    recipientIsSender: recipientIsSender,
    confirmationCode: confirmationCode,
    trackingToken: trackingToken,
    recipientName: recipientName,
    travelerName: travelerName,
    senderName: senderName,
    departureCity: 'Paris',
    arrivalCity: arrivalCity,
  );

  group('rôle du lecteur', () {
    test('expéditeur, voyageur, inconnu', () {
      expect(bidViewerRoles(bid(), sender), {ParcelRole.sender});
      expect(bidViewerRoles(bid(), traveler), {ParcelRole.traveler});
      expect(bidViewerRoles(bid(), 'autre'), isEmpty);
      expect(bidViewerRoles(bid(), null), isEmpty);
      expect(bidViewerRoles(BidModel.skeleton('bid-1'), sender), isEmpty);
    });

    test('voyageur inconnu du colis : la vue voyageur, comme la fiche', () {
      expect(bidViewerRoles(bid(travelerId: null), 'x'), {ParcelRole.traveler});
    });

    test('expéditeur qui est son propre destinataire : les deux rôles', () {
      expect(bidViewerRoles(bid(recipientIsSender: true), sender), {
        ParcelRole.sender,
        ParcelRole.recipient,
      });
      // Le drapeau ne change rien pour le voyageur.
      expect(bidViewerRoles(bid(recipientIsSender: true), traveler), {
        ParcelRole.traveler,
      });
    });
  });

  group('étape', () {
    test('statut des rails : son déclencheur', () {
      for (final (status, trigger) in [
        ('ACCEPTED', VideoModalTrigger.parcelAccepted),
        ('HANDED_OVER', VideoModalTrigger.parcelHandedOver),
        ('IN_TRANSIT', VideoModalTrigger.parcelInTransit),
        ('ARRIVED', VideoModalTrigger.parcelArrived),
        ('COMPLETED', VideoModalTrigger.parcelDelivered),
      ]) {
        final m = bidParcelStepMoment(bid(status: status), viewerId: sender);
        expect(m?.trigger, trigger, reason: status);
        expect(m?.parcel?.bidId, 'bid-1');
      }
    });

    test('outOfRailsStatus_emitsNoMoment', () {
      for (final status in [
        'CANCELLED',
        'NO_SHOW',
        'PARCEL_REFUSED',
        'EXPIRED',
        'NEGOTIATING',
        'NEGOTIATION_CLOSED',
        'AWAITING_PAYMENT',
        'PENDING',
        'PAYMENT_ESCROWED',
        'REJECTED',
      ]) {
        expect(
          bidParcelStepMoment(bid(status: status), viewerId: sender),
          isNull,
          reason: status,
        );
      }
    });

    test('lecteur sans rôle : aucun moment', () {
      expect(bidParcelStepMoment(bid(), viewerId: 'autre'), isNull);
      expect(bidParcelStepMoment(bid(), viewerId: null), isNull);
    });
  });

  group('variables', () {
    test('noms et ville du colis, jamais le code', () {
      final m = bidParcelStepMoment(bid(), viewerId: sender)!;
      expect(m.variables, {
        'destinataire': 'Awa Diop',
        'voyageur': 'Moussa',
        'expéditeur': 'Fatou',
        'ville_arrivee': 'Dakar',
      });
      for (final v in m.variables.values) {
        expect(v.contains('482913'), isFalse);
      }
    });

    test('noms absents : vides, le repli est posé à l\'ouverture', () {
      final m = bidParcelStepMoment(
        bid(
          recipientName: null,
          travelerName: null,
          senderName: null,
          arrivalCity: null,
        ),
        viewerId: traveler,
      )!;
      expect(m.variables.values.every((v) => v.isEmpty), isTrue);
    });
  });

  group('boutons possibles', () {
    test('expéditeur, code présent et message possible : tout', () {
      final p = bidParcelStepMoment(
        bid(status: 'HANDED_OVER'),
        viewerId: sender,
      )!.parcel!;
      expect(p.canRun(InfoScreen.parcelQr), isTrue);
      expect(p.canRun(InfoScreen.parcelSendCode), isTrue);
      expect(p.canRun(InfoScreen.parcelTracking), isTrue);
      expect(p.canRun(InfoScreen.parcelDetail), isTrue);
    });

    test('sendCodeButtonHiddenWithoutCode', () {
      final p = bidParcelStepMoment(
        bid(status: 'HANDED_OVER', confirmationCode: null),
        viewerId: sender,
      )!.parcel!;
      expect(p.canSendCode, isFalse);
      expect(p.canRun(InfoScreen.parcelSendCode), isFalse);
      // Avant la remise, le code n'existe pas.
      expect(
        bidParcelStepMoment(
          bid(status: 'ACCEPTED'),
          viewerId: sender,
        )!.parcel!.canRun(InfoScreen.parcelSendCode),
        isFalse,
      );
    });

    test("expéditeur qui est son propre destinataire : pas d'envoi à soi", () {
      final p = bidParcelStepMoment(
        bid(status: 'HANDED_OVER', recipientIsSender: true),
        viewerId: sender,
      )!.parcel!;
      expect(p.canRun(InfoScreen.parcelSendCode), isFalse);
      expect(p.canRun(InfoScreen.parcelQr), isTrue);
    });

    test('voyageur : ni QR ni code, le suivi oui', () {
      final p = bidParcelStepMoment(bid(), viewerId: traveler)!.parcel!;
      expect(p.canRun(InfoScreen.parcelQr), isFalse);
      expect(p.canRun(InfoScreen.parcelSendCode), isFalse);
      expect(p.canRun(InfoScreen.parcelTracking), isTrue);
      expect(p.detailRoute, '/bids/bid-1');
    });
  });
}
