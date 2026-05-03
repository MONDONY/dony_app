enum MessageType { text, image, location, system }

class MessageModel {
  final String id;
  final String senderId;
  final String? body;
  final String? imageUrl;
  final MessageType type;
  final DateTime sentAt;
  final DateTime? readAt;
  final String? deletedAt;
  // Location message fields
  final double? latitude;
  final double? longitude;

  const MessageModel({
    required this.id,
    required this.senderId,
    this.body,
    this.imageUrl,
    required this.type,
    required this.sentAt,
    this.readAt,
    this.deletedAt,
    this.latitude,
    this.longitude,
  });

  bool get isDeleted => deletedAt != null;

  factory MessageModel.fromFirestore(String id, Map<String, dynamic> data) {
    final typeStr = data['type'] as String? ?? 'TEXT';
    final type = switch (typeStr) {
      'IMAGE' => MessageType.image,
      'LOCATION' => MessageType.location,
      'SYSTEM' => MessageType.system,
      _ => MessageType.text,
    };
    return MessageModel(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      body: data['body'] as String?,
      imageUrl: data['imageUrl'] as String?,
      type: type,
      sentAt: _parseTs(data['sentAt']),
      readAt: data['readAt'] != null ? _parseTs(data['readAt']) : null,
      deletedAt: data['deletedAt'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  static DateTime _parseTs(dynamic val) {
    if (val == null) return DateTime.now().toUtc();
    if (val is String) {
      final parsed = DateTime.tryParse(val);
      if (parsed == null) return DateTime.now().toUtc();
      return parsed.isUtc ? parsed : parsed.toUtc();
    }
    return DateTime.now().toUtc();
  }
}
