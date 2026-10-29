import 'package:dony/core/error/error_catalog.dart';
import 'package:dony/features/matching/bloc/bid_acceptance_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/l10n/l10n.dart';

/// Libellé court sous le montant de la carte de liste des discussions de prix.
extension BidNegotiationStageL10n on BidNegotiationSummary {
  String stageLabel(AppLocalizations l) {
    if (isAwaitingCardPayment) {
      return needsMyPayment
          ? l.negotiationStageToPay
          : l.negotiationStageAwaitingPayment;
    }
    if (isAwaitingCashSettlement) {
      return l.negotiationStageDealAgreed;
    }
    if (isClosed) {
      return l.negotiationStageClosed;
    }
    return l.negotiationStageProposal;
  }
}

/// Nom à afficher pour l'expéditeur. Le téléphone ne sert plus de repli : il
/// n'est plus dans la réponse, et un numéro affiché en guise de nom se lisait
/// mal.
extension BidSenderName on BidModel {
  String senderDisplayName(AppLocalizations l) {
    if (senderName != null && senderName!.isNotEmpty) return senderName!;
    return l.bidSenderFallbackName;
  }
}

/// Nombre de trajets déjà effectués par le voyageur, composable dans une ligne
/// compacte (« · 3 trajets ») aussi bien depuis les cartes de bid que, plus
/// tard, depuis les cartes de contact (partie D).
String travelerTripsCount(AppLocalizations l, int count) =>
    l.bidTravelerTrips(count);

/// Nombre d'envois déjà effectués par l'expéditeur, même usage composable que
/// [travelerTripsCount].
String senderShipmentsCount(AppLocalizations l, int count) =>
    l.bidSenderShipments(count);

/// Texte à afficher pour un [BidFailed] : le detail serveur (`serverMessage`)
/// prime quand il existe, sinon la clé de la raison — le bloc ne transporte
/// jamais de texte traduit.
///
/// Exception : [BidFailureReason.confirmFailed]. Son `serverMessage` vient de
/// `ConfirmAcceptanceResponse.fail(...)` (`CashCommissionService`, back), qui
/// ne passe jamais par `messagesResolver` — contrairement au `serverMessage`
/// de [BidFailureReason.refused] (`AcceptBidResponse.failed`, traduit). Un
/// utilisateur anglais verrait donc du français : on ignore ce
/// `serverMessage` et on affiche toujours le texte du catalogue (relecture
/// finale du lot K).
extension BidFailedDisplay on BidFailed {
  String displayMessage(AppLocalizations l) {
    // Refus métier du serveur au code connu (trajet complet, trajet fermé…) :
    // message précis du catalogue plutôt que « Acceptation refusée ».
    final err = error;
    if (err != null && ErrorCatalog.isKnown(err)) {
      return ErrorCatalog.lookup(err, l10n: l).message;
    }
    switch (reason) {
      case BidFailureReason.confirmFailed:
        return l.bidAcceptConfirmFailed;
      case BidFailureReason.bankAuthInterrupted:
        final sm = serverMessage;
        if (sm != null && sm.trim().isNotEmpty) return sm;
        return l.bidAcceptBankAuthInterrupted;
      case BidFailureReason.refused:
        final sm = serverMessage;
        if (sm != null && sm.trim().isNotEmpty) return sm;
        return l.bidAcceptRefused;
    }
  }
}

/// Statuts où expéditeur et voyageur peuvent se contacter (appel, message) :
/// la demande est acceptée ou au-delà. Avant (en attente de paiement ou
/// d'acceptation), chacun voit le profil de l'autre mais sans moyen de le
/// joindre, et le voyageur ne voit pas le téléphone du destinataire.
const bidContactStatuses = <String>{
  'ACCEPTED',
  'HANDED_OVER',
  'IN_TRANSIT',
  'ARRIVED',
  'COMPLETED',
  'DELIVERED',
};

bool bidAllowsContact(String status) => bidContactStatuses.contains(status);

/// Statuts où le VOYAGEUR peut joindre le destinataire (appel, WhatsApp, SMS,
/// numéro affiché) : seulement après le retrait du colis. Plus étroit que
/// [bidContactStatuses], qui règle le contact expéditeur ↔ voyageur et reste
/// ouvert dès `ACCEPTED` (décision produit du 11/10/2026, Sentry FLUTTER-JT).
///
/// Appliqué côté app même si le serveur sert encore le numéro à `ACCEPTED`
/// (ancien contrat) : il n'est alors simplement pas affiché.
const bidRecipientContactStatuses = <String>{
  'HANDED_OVER',
  'IN_TRANSIT',
  'ARRIVED',
  'COMPLETED',
  'DELIVERED',
};

bool bidAllowsRecipientContact(String status) =>
    bidRecipientContactStatuses.contains(status);

/// Statuts où le VOYAGEUR voit le numéro de suivi du colis : à partir de la
/// remise (départ scanné). Avant, ou sur une demande close sans remise, il ne
/// le voit nulle part. Même ensemble que [bidRecipientContactStatuses], mais
/// c'est une autre règle (visibilité du numéro, décision du propriétaire) :
/// elle reste nommée à part.
const bidTrackingNumberTravelerStatuses = <String>{
  'HANDED_OVER',
  'IN_TRANSIT',
  'ARRIVED',
  'COMPLETED',
  'DELIVERED',
};

/// Numéro de suivi du colis tel que le VOYAGEUR a le droit de le voir : le
/// numéro à partir de la remise ([bidTrackingNumberTravelerStatuses]), `null`
/// avant (demande en attente, acceptée, refusée, annulée...), et `null` si le
/// serveur n'en a pas servi.
///
/// Le back ne l'envoie déjà qu'à partir de la remise ; l'app le garantit
/// elle-même (défense en profondeur) aux trois emplacements voyageur : bande
/// du talon, titre de l'écran, ligne « Numéro de suivi » de « Plus de
/// détails ». Côté expéditeur, on lit `bid.trackingNumber` directement.
String? travelerVisibleTrackingNumber(BidModel bid) {
  final number = bid.trackingNumber;
  if (number == null || number.trim().isEmpty) return null;
  return bidTrackingNumberTravelerStatuses.contains(bid.status) ? number : null;
}

/// Retour en cours d'un colis annulé alors que le voyageur l'avait déjà
/// (FLUTTER-FM) : expéditeur et voyageur doivent pouvoir s'écrire et
/// s'appeler pour organiser la restitution, jusqu'à ce qu'elle soit confirmée
/// ou que le délai de retour soit écoulé.
///
/// La fenêtre vient du serveur (`contactWindowOpen`, qui couvre le retour
/// depuis yadony-back « annulation-retour ») ; un back antérieur la sert à
/// `false` sur un colis annulé, le contact reste alors fermé comme avant.
/// Sans le champ, repli sur le délai de retour lu par l'app.
bool bidReturnInProgress(BidModel bid, {DateTime? now}) {
  if (bid.status != 'CANCELLED' || !bid.isAwaitingReturn) return false;
  final open = bid.contactWindowOpen;
  if (open != null) return open;
  return (now ?? DateTime.now()).isBefore(bid.returnDeadline!);
}

/// Commande annulée en cours de route, sans retour de colis à organiser :
/// le serveur garde le contact expéditeur ↔ voyageur (appel in-app, numéro,
/// photos) ouvert 48 h après l'annulation (FLUTTER-P1, yadony-back #514), et
/// le dit par `contactWindowOpen`. Champ absent ou faux : fermé comme avant.
///
/// Ne concerne jamais le destinataire ([bidAllowsRecipientContact] inchangé).
bool bidCancelledContactOpen(BidModel bid, {DateTime? now}) =>
    bid.status == 'CANCELLED' &&
    bid.contactWindowOpen == true &&
    !bidReturnInProgress(bid, now: now);

/// [bidAllowsContact], retour d'un colis annulé compris ([bidReturnInProgress])
/// et fenêtre de 48 h après l'annulation ([bidCancelledContactOpen]).
bool bidAllowsContactFor(BidModel bid, {DateTime? now}) =>
    bidAllowsContact(bid.status) ||
    bidReturnInProgress(bid, now: now) ||
    bidCancelledContactOpen(bid, now: now);

/// Statuts d'une demande pas encore acceptée : les cartes de profil y
/// expliquent quand le contact deviendra possible (FLUTTER-4T).
const bidContactPendingStatuses = <String>{
  'PENDING',
  'PAYMENT_ESCROWED',
  'AWAITING_PAYMENT',
};
