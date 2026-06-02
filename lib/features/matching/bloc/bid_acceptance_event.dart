abstract class BidAcceptanceEvent {}

class BidAcceptRequested extends BidAcceptanceEvent {
  final String bidId;
  BidAcceptRequested(this.bidId);
}

/// Retry forcé avec la carte de commission (choisi par le voyageur après solde insuffisant).
class BidAcceptWithCardRequested extends BidAcceptanceEvent {
  final String bidId;
  BidAcceptWithCardRequested(this.bidId);
}
