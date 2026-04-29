enum MessageType { text, image, system }

class MessageModel {
  final String id;
  final String senderId;
  final String? body;
  final String? imageUrl;
  final MessageType type;
  final DateTime sentAt;
  final DateTime? readAt;
  final String? deletedAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    this.body,
    this.imageUrl,
    required this.type,
    required this.sentAt,
    this.readAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  factory MessageModel.fromFirestore(String id, Map<String, dynamic> data) {
    final typeStr = data['type'] as String? ?? 'TEXT';
    final type = switch (typeStr) {
      'IMAGE' => MessageType.image,
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
    );
  }

  static DateTime _parseTs(dynamic val) {
    if (val == null) {
      return DateTime.now();
    }
    if (val is String) {
      return DateTime.tryParse(val) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
