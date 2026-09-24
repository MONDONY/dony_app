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
