import 'package:dony/features/matching/data/models/bid_checkout_response_model.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';

abstract class BidState {}

/// Helper exposant les bids actifs (PENDING / ACCEPTED) du sender courant
/// indexés par `announcementId`. Utilisé pour annoter les cartes de trajets
/// déjà couverts par une demande, afin d'éviter un double bid et d'orienter
/// l'utilisateur vers le détail de SA demande au lieu du détail du trajet.
extension MyActiveBidsLookup on BidState {
  Map<String, BidModel> activeBidsByAnnouncement() {
    final state = this;
    if (state is! BidListLoaded) return const {};
    final result = <String, BidModel>{};
    for (final bid in state.bids) {
      if (bid.status == 'PENDING' || bid.status == 'ACCEPTED') {
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
  final String message;
  BidError(this.message);
}

class BidNotFound extends BidState {}

class BidPaymentConfirmed extends BidState {
  final BidModel bid;
  BidPaymentConfirmed(this.bid);
}
