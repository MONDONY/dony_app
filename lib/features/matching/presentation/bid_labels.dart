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
