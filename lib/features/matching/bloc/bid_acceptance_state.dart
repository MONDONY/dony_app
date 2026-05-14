abstract class BidAcceptanceState {}

class BidAcceptanceInitial extends BidAcceptanceState {}

class BidAccepting extends BidAcceptanceState {}

class BidAccepted extends BidAcceptanceState {}

class BidFailed extends BidAcceptanceState {
  final String message;
  BidFailed(this.message);
}
