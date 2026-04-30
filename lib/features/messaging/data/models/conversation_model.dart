import 'package:intl/intl.dart';

class ParticipantModel {
  final String id;
  final String name;
  final String? avatarUrl;

  const ParticipantModel({required this.id, required this.name, this.avatarUrl});

  factory ParticipantModel.fromJson(Map<String, dynamic> json) => ParticipantModel(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String?,
      );
}

class ConversationModel {
  final String id;
  final String bidId;
  final String firestoreConversationId;
  final ParticipantModel otherParticipant;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final bool hasUnread;
  final int unreadCount;
  // Trip metadata — populated by backend
  final String? tripOrigin;
  final String? tripDestination;
  final DateTime? tripDate;
  final double? tripWeightKg;
  // BID_ACCEPTED | DELIVERY_CONFIRMED | TRIP_CANCELLED
  final String? bidStatus;

  const ConversationModel({
    required this.id,
    required this.bidId,
    required this.firestoreConversationId,
    required this.otherParticipant,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.hasUnread = false,
    this.unreadCount = 0,
    this.tripOrigin,
    this.tripDestination,
    this.tripDate,
    this.tripWeightKg,
    this.bidStatus,
  });

  /// Formatted trip label for display, e.g. "Paris → Dakar · 12 jan · 5 kg"
  String? get tripLabel {
    if (tripOrigin == null || tripDestination == null) return null;
    final parts = <String>['$tripOrigin → $tripDestination'];
    if (tripDate != null) parts.add(DateFormat('d MMM', 'fr').format(tripDate!));
    if (tripWeightKg != null) parts.add('${tripWeightKg!.toStringAsFixed(0)} kg');
    return parts.join(' · ');
  }

  ConversationModel copyWith({
    bool? hasUnread,
    int? unreadCount,
    String? lastMessagePreview,
    DateTime? lastMessageAt,
  }) =>
      ConversationModel(
        id: id,
        bidId: bidId,
        firestoreConversationId: firestoreConversationId,
        otherParticipant: otherParticipant,
        lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        hasUnread: hasUnread ?? this.hasUnread,
        unreadCount: unreadCount ?? this.unreadCount,
        tripOrigin: tripOrigin,
        tripDestination: tripDestination,
        tripDate: tripDate,
        tripWeightKg: tripWeightKg,
        bidStatus: bidStatus,
      );

  factory ConversationModel.fromJson(Map<String, dynamic> json) => ConversationModel(
        id: json['id'] as String,
        bidId: json['bidId'] as String,
        firestoreConversationId: json['firestoreConversationId'] as String,
        otherParticipant:
            ParticipantModel.fromJson(json['otherParticipant'] as Map<String, dynamic>),
        lastMessagePreview: json['lastMessagePreview'] as String?,
        lastMessageAt: json['lastMessageAt'] != null
            ? DateTime.tryParse(json['lastMessageAt'] as String)
            : null,
        hasUnread: json['hasUnread'] as bool? ?? false,
        unreadCount: json['unreadCount'] as int? ?? 0,
        tripOrigin: json['tripOrigin'] as String?,
        tripDestination: json['tripDestination'] as String?,
        tripDate: json['tripDate'] != null
            ? DateTime.tryParse(json['tripDate'] as String)
            : null,
        tripWeightKg: (json['tripWeightKg'] as num?)?.toDouble(),
        bidStatus: json['bidStatus'] as String?,
      );
}
