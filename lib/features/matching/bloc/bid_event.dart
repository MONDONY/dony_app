abstract class BidEvent {}

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
