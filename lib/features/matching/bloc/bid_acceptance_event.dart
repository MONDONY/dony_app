abstract class BidAcceptanceEvent {}

class BidAcceptRequested extends BidAcceptanceEvent {
  final String bidId;
  BidAcceptRequested(this.bidId);
}

class _BidAcceptanceConfirmed extends BidAcceptanceEvent {
  final String bidId;
  _BidAcceptanceConfirmed(this.bidId);
}
