/// Une ligne du feed de notifications.
///
/// Soit une notification seule ([count] = 1), soit l'agrégat d'un groupe non
/// lu servi par le serveur ([count] ≥ 3) : [id], [body] et [data] sont alors
/// ceux de la plus récente, [title] et [deeplink] ceux du groupe, et
/// [notificationIds] liste tout ce que la ligne recouvre. Lire un agrégat
/// passe par sa [groupKey], jamais par son [id] seul.
class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  /// `colis` | `trajets` | `paiements` | `annonce` ; vide sur l'ancienne liste.
  final String category;

  /// Destination `yadony://host/path` décidée par le serveur, nulle pour une
  /// annonce plateforme (qui ouvre le détail générique).
  final String? deeplink;

  /// Clé d'agrégation ; `notif:{id}` pour une ligne seule.
  final String? groupKey;

  /// Nombre de notifications recouvertes par la ligne (1 hors agrégat).
  final int count;

  /// Ids recouverts, dans l'ordre de la plus récente à la plus ancienne.
  final List<String> notificationIds;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    required this.createdAt,
    this.category = '',
    this.deeplink,
    this.groupKey,
    this.count = 1,
    List<String>? notificationIds,
  }) : notificationIds = notificationIds ?? const [];

  bool get isAggregate => count > 1;

  /// La route GoRouter portée par [deeplink] (`yadony://bids/x` → `/bids/x`),
  /// nulle sans deeplink.
  String? get deeplinkRoute {
    final link = deeplink;
    if (link == null || link.isEmpty) return null;
    final uri = Uri.tryParse(link);
    if (uri == null || uri.host.isEmpty) return null;
    return '/${uri.host}${uri.path}';
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final ids = (json['notificationIds'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();
    return NotificationModel(
      id: id,
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      category: json['category'] as String? ?? '',
      deeplink: json['deeplink'] as String?,
      groupKey: json['groupKey'] as String?,
      count: (json['count'] as num?)?.toInt() ?? 1,
      notificationIds: ids == null || ids.isEmpty ? [id] : ids,
    );
  }

  NotificationModel copyWith({bool? read}) {
    return NotificationModel(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data,
      read: read ?? this.read,
      createdAt: createdAt,
      category: category,
      deeplink: deeplink,
      groupKey: groupKey,
      count: count,
      notificationIds: notificationIds,
    );
  }
}
