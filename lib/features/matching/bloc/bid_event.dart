abstract class BidEvent {
  const BidEvent();
}

class BidCheckoutRequested extends BidEvent {
  final String announcementId;
  final double weightKg;
  final double declaredValueEur;
  final String description;
  final String contentCategory;
  final String recipientName;
  final String recipientPhone;

  BidCheckoutRequested({
    required this.announcementId,
    required this.weightKg,
    required this.declaredValueEur,
    required this.description,
    required this.contentCategory,
    required this.recipientName,
    required this.recipientPhone,
  });
}

class BidCreateRequested extends BidEvent {
  final String announcementId;
  final double weightKg;
  final double declaredValueEur;
  final String description;
  final String contentCategory;
  final String recipientName;
  final String recipientPhone;

  BidCreateRequested({
    required this.announcementId,
    required this.weightKg,
    required this.declaredValueEur,
    required this.description,
    required this.contentCategory,
    required this.recipientName,
    required this.recipientPhone,
  });
}

class BidListRequested extends BidEvent {
  final String announcementId;
  BidListRequested(this.announcementId);
}

class BidMyListRequested extends BidEvent {}

/// Rafraîchit la liste si les données sont périmées (TTL 3 min).
/// [force] = true bypasse le TTL (pull-to-refresh manuel).
class BidMyListAutoRefreshRequested extends BidEvent {
  final bool force;
  const BidMyListAutoRefreshRequested({this.force = false});
}

class BidDetailRequested extends BidEvent {
  final String bidId;
  BidDetailRequested(this.bidId);
}

class BidAcceptRequested extends BidEvent {
  final String bidId;
  BidAcceptRequested(this.bidId);
}

class BidRejectRequested extends BidEvent {
  final String bidId;
  final String? reason;
  BidRejectRequested(this.bidId, {this.reason});
}

class BidHandoverRequested extends BidEvent {
  final String bidId;
  final String location;
  final DateTime windowStart;
  final DateTime windowEnd;

  BidHandoverRequested({
    required this.bidId,
    required this.location,
    required this.windowStart,
    required this.windowEnd,
  });
}

class BidConfirmPresenceRequested extends BidEvent {
  final String bidId;
  BidConfirmPresenceRequested(this.bidId);
}

class BidCancelRequested extends BidEvent {
  final String bidId;
  final String? reason;
  BidCancelRequested(this.bidId, {this.reason});
}

class BidHideRequested extends BidEvent {
  final String bidId;
  BidHideRequested(this.bidId);
}

class BidDeleteRequested extends BidEvent {
  final String bidId;
  BidDeleteRequested(this.bidId);
}

class BidTravelerDismissRequested extends BidEvent {
  final String bidId;
  BidTravelerDismissRequested(this.bidId);
}

/// Synchronously confirms with the backend that the Stripe PaymentIntent
/// has been authorized. Promotes the bid from AWAITING_PAYMENT to PENDING
/// without waiting for the Stripe webhook (safety net for local dev and
/// network failures).
class BidConfirmPaymentRequested extends BidEvent {
  final String bidId;
  BidConfirmPaymentRequested(this.bidId);
}
