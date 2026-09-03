/// Une notification seule avec son texte complet, servie par
/// `GET /notifications/{id}`. C'est l'écran de détail générique qui la lit,
/// pour une ligne sans deeplink (une annonce plateforme) : le texte complet
/// n'existe nulle part ailleurs dans l'app.
class NotificationDetail {
  final String id;
  final String type;
  final String category;
  final String title;
  final String body;
  final String? fullBody;
  final bool read;
  final DateTime createdAt;

  const NotificationDetail({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.fullBody,
  });

  /// Le texte à afficher : complet quand il existe, sinon le corps court.
  String get text {
    final full = fullBody;
    return full == null || full.isEmpty ? body : full;
  }

  factory NotificationDetail.fromJson(Map<String, dynamic> json) {
    return NotificationDetail(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      category: json['category'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      fullBody: json['fullBody'] as String?,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
