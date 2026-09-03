/// La carte « Annonces Yadony » en tête du sheet : son compteur de non-lus et
/// la dernière annonce reçue, servis par `GET /notifications/annonces/summary`.
class AnnouncementsSummary {
  final int unreadCount;
  final String? latestId;
  final String? latestTitle;
  final DateTime? latestAt;

  const AnnouncementsSummary({
    required this.unreadCount,
    this.latestId,
    this.latestTitle,
    this.latestAt,
  });

  static const empty = AnnouncementsSummary(unreadCount: 0);

  bool get hasAny => latestId != null;

  factory AnnouncementsSummary.fromJson(Map<String, dynamic> json) {
    final at = json['latestAt'] as String?;
    return AnnouncementsSummary(
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      latestId: json['latestId'] as String?,
      latestTitle: json['latestTitle'] as String?,
      latestAt: at == null ? null : DateTime.tryParse(at),
    );
  }

  AnnouncementsSummary copyWith({int? unreadCount}) => AnnouncementsSummary(
    unreadCount: unreadCount ?? this.unreadCount,
    latestId: latestId,
    latestTitle: latestTitle,
    latestAt: latestAt,
  );
}
