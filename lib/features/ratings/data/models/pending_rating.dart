class PendingRating {
  const PendingRating({
    required this.bidId,
    required this.otherPartyName,
    required this.otherPartyId,
    required this.deliveredAt,
    required this.isTravelerRating,
  });

  final String bidId;
  final String otherPartyName;
  final String otherPartyId;
  final DateTime deliveredAt;
  final bool isTravelerRating;

  factory PendingRating.fromJson(Map<String, dynamic> json) => PendingRating(
    bidId: json['bidId'] as String,
    otherPartyName: json['otherPartyName'] as String,
    otherPartyId: json['otherPartyId'] as String,
    deliveredAt: DateTime.parse(json['deliveredAt'] as String),
    isTravelerRating: json['isTravelerRating'] as bool? ?? false,
  );
}
