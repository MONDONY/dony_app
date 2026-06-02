import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_quote_response.dart';

abstract class BidState {}

/// Helper exposant les bids actifs du sender courant indexés par
/// `announcementId`. Couvre tous les statuts qui signifient qu'une demande
/// est déjà en cours : AWAITING_PAYMENT (paiement non encore effectué),
/// PENDING (en attente de réponse du voyageur), PAYMENT_ESCROWED et ACCEPTED.
extension MyActiveBidsLookup on BidState {
  Map<String, BidModel> activeBidsByAnnouncement() {
    final state = this;
    if (state is! BidListLoaded) return const {};
    final result = <String, BidModel>{};
    for (final bid in state.bids) {
      if (bid.status == 'AWAITING_PAYMENT' ||
          bid.status == 'PENDING' ||
          bid.status == 'PAYMENT_ESCROWED' ||
          bid.status == 'ACCEPTED') {
        result[bid.announcementId] = bid;
      }
    }
    return result;
  }
}

class BidInitial extends BidState {}

class BidLoading extends BidState {}

class BidCheckoutReady extends BidState {
  final BidCheckoutResponseModel response;
  BidCheckoutReady(this.response);
}

class BidCreated extends BidState {
  final BidModel bid;
  BidCreated(this.bid);
}

class BidListLoaded extends BidState {
  final List<BidModel> bids;
  final DateTime fetchedAt;
  final bool isRefreshing;

  BidListLoaded(
    this.bids, {
    DateTime? fetchedAt,
    this.isRefreshing = false,
  }) : fetchedAt = fetchedAt ?? DateTime.now();
}

class BidDetailLoaded extends BidState {
  final BidModel bid;
  BidDetailLoaded(this.bid);
}

class BidAccepted extends BidState {
  final BidModel bid;
  BidAccepted(this.bid);
}

class BidRejected extends BidState {
  final BidModel bid;
  BidRejected(this.bid);
}

class BidHandoverSet extends BidState {
  final BidModel bid;
  BidHandoverSet(this.bid);
}

class BidPresenceConfirmed extends BidState {
  final BidModel bid;
  BidPresenceConfirmed(this.bid);
}

class BidCancelled extends BidState {
  final BidModel bid;
  BidCancelled(this.bid);
}

class BidHidden extends BidState {}

class BidDeleted extends BidState {}

class BidError extends BidState {
  final AppException error;
  BidError(this.error);
}

class BidNotFound extends BidState {}

class BidPaymentConfirmed extends BidState {
  final BidModel bid;
  BidPaymentConfirmed(this.bid);
}

/// Devis calculé avec succès — affichage total + promo.
class BidQuoteLoaded extends BidState {
  final BidQuoteResponse quote;
  BidQuoteLoaded(this.quote);
}

/// Calcul du devis en cours (spinner dans le champ promo).
class BidQuoteLoading extends BidState {}

/// Promo invalide (expiré, introuvable, limite atteinte).
class BidPromoError extends BidState {
  final AppException error;
  BidPromoError(this.error);
}
