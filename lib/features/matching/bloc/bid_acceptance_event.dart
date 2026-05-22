abstract class BidAcceptanceEvent {}

class BidAcceptRequested extends BidAcceptanceEvent {
  final String bidId;
  BidAcceptRequested(this.bidId);
}
