class SubscriptionStatus {
  final bool subscribed;
  final bool pushEnabled;
  const SubscriptionStatus({
    required this.subscribed,
    required this.pushEnabled,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) =>
      SubscriptionStatus(
        subscribed: json['subscribed'] as bool? ?? false,
        pushEnabled: json['pushEnabled'] as bool? ?? false,
      );
}

class TravelerAnnouncement {
  final String id;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureDate;
  final double pricePerKg;
  final double availableKg;
  final String status;
  final String currency;
  const TravelerAnnouncement({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    required this.pricePerKg,
    required this.availableKg,
    required this.status,
    this.currency = 'EUR',
  });

  factory TravelerAnnouncement.fromJson(Map<String, dynamic> json) =>
      TravelerAnnouncement(
        id: json['id'] as String,
        departureCity: json['departureCity'] as String,
        arrivalCity: json['arrivalCity'] as String,
        departureDate: DateTime.parse(json['departureDate'] as String),
        pricePerKg: (json['pricePerKg'] as num).toDouble(),
        availableKg: (json['availableKg'] as num).toDouble(),
        status: json['status'] as String,
        currency: json['currency'] as String? ?? 'EUR',
      );
}

class LastAnnouncement {
  final String announcementId;
  final String departureCity;
  final String arrivalCity;
  final double pricePerKg;
  final DateTime publishedAt;
  const LastAnnouncement({
    required this.announcementId,
    required this.departureCity,
    required this.arrivalCity,
    required this.pricePerKg,
    required this.publishedAt,
  });

  factory LastAnnouncement.fromJson(Map<String, dynamic> json) =>
      LastAnnouncement(
        announcementId: json['announcementId'] as String,
        departureCity: json['departureCity'] as String,
        arrivalCity: json['arrivalCity'] as String,
        pricePerKg: (json['pricePerKg'] as num).toDouble(),
        publishedAt: DateTime.parse(json['publishedAt'] as String),
      );
}

class SubscriptionItem {
  final String travelerId;
  final String travelerName;
  final String? avatarUrl;
  final bool isProAccount;
  final double? averageRating;
  final int ongoingTripsCount;
  final bool pushEnabled;
  final bool hasNew;
  final LastAnnouncement? lastAnnouncement;
  const SubscriptionItem({
    required this.travelerId,
    required this.travelerName,
    this.avatarUrl,
    required this.isProAccount,
    required this.averageRating,
    required this.ongoingTripsCount,
    required this.pushEnabled,
    required this.hasNew,
    required this.lastAnnouncement,
  });

  SubscriptionItem copyWith({bool? pushEnabled}) => SubscriptionItem(
    travelerId: travelerId,
    travelerName: travelerName,
    avatarUrl: avatarUrl,
    isProAccount: isProAccount,
    averageRating: averageRating,
    ongoingTripsCount: ongoingTripsCount,
    pushEnabled: pushEnabled ?? this.pushEnabled,
    hasNew: hasNew,
    lastAnnouncement: lastAnnouncement,
  );

  factory SubscriptionItem.fromJson(Map<String, dynamic> json) =>
      SubscriptionItem(
        travelerId: json['travelerId'] as String,
        travelerName: json['travelerName'] as String? ?? 'Voyageur',
        avatarUrl: json['avatarUrl'] as String?,
        isProAccount: json['isProAccount'] as bool? ?? false,
        averageRating: (json['averageRating'] as num?)?.toDouble(),
        ongoingTripsCount: (json['ongoingTripsCount'] as num?)?.toInt() ?? 0,
        pushEnabled: json['pushEnabled'] as bool? ?? false,
        hasNew: json['hasNew'] as bool? ?? false,
        lastAnnouncement: json['lastAnnouncement'] == null
            ? null
            : LastAnnouncement.fromJson(
                json['lastAnnouncement'] as Map<String, dynamic>,
              ),
      );
}

abstract class SubscriptionsRepository {
  Future<List<SubscriptionItem>> getMySubscriptions();
  Future<void> unsubscribe(String travelerId);
  Future<SubscriptionStatus> setPush(String travelerId, bool enabled);
  Future<SubscriptionStatus> getStatus(String travelerId);
  Future<void> subscribe(String travelerId);
  Future<void> markSeen(String travelerId);
  Future<List<TravelerAnnouncement>> getTravelerAnnouncements(
    String travelerId,
  );
}
