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

  /// Id Firestore du message cité (même conversation), `null` hors réponse
  /// (FLUTTER-86). Seule la référence est stockée, jamais d'extrait : la
  /// citation est reconstituée à l'affichage, et suit donc une suppression.
  final String? replyToId;

  /// Photo stockée par le back (FLUTTER-B4) : clés R2 écrites par le serveur,
  /// jamais par un client. Leur seule présence dit que l'image se charge par
  /// l'API (`GET /conversations/{id}/messages/{messageId}/image`) ; un ancien
  /// message image n'a que [imageUrl], une URL signée lue telle quelle.
  final String? imageKey;
  final String? thumbKey;

  /// Photo purgée par le back (conservation dépassée) : le message reste,
  /// l'image s'affiche « Photo expirée » sans requête.
  final bool imageExpired;

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
    this.replyToId,
    this.imageKey,
    this.thumbKey,
    this.imageExpired = false,
  });

  /// Photo servie par l'API du back (et non par une URL signée historique).
  bool get isServerImage => type == MessageType.image && imageKey != null;

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
      replyToId: _replyToId(data['replyToId']),
      imageKey: _nonBlank(data['imageKey']),
      thumbKey: _nonBlank(data['thumbKey']),
      imageExpired: data['imageExpired'] == true,
    );
  }

  static String? _nonBlank(dynamic val) =>
      val is String && val.trim().isNotEmpty ? val : null;

  /// Les règles Firestore n'acceptent qu'un id `[A-Za-z0-9]{1,40}` : toute
  /// autre valeur (document ancien ou altéré) est ignorée plutôt que de
  /// faire échouer la lecture de tout le fil.
  static String? _replyToId(dynamic val) =>
      val is String && validReplyToId.hasMatch(val) ? val : null;

  /// Forme d'un id de message citable (miroir des règles Firestore).
  static final validReplyToId = RegExp(r'^[A-Za-z0-9]{1,40}$');

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
