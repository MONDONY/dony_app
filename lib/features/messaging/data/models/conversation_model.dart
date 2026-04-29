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

  const ConversationModel({
    required this.id,
    required this.bidId,
    required this.firestoreConversationId,
    required this.otherParticipant,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.hasUnread = false,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) => ConversationModel(
        id: json['id'] as String,
        bidId: json['bidId'] as String,
        firestoreConversationId: json['firestoreConversationId'] as String,
        otherParticipant: ParticipantModel.fromJson(json['otherParticipant'] as Map<String, dynamic>),
        lastMessagePreview: json['lastMessagePreview'] as String?,
        lastMessageAt: json['lastMessageAt'] != null
            ? DateTime.tryParse(json['lastMessageAt'] as String)
            : null,
        hasUnread: json['hasUnread'] as bool? ?? false,
      );
}
