import 'package:dony/features/matching/data/models/bid_model.dart';

abstract class BidState {}

class BidInitial extends BidState {}

class BidLoading extends BidState {}

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
