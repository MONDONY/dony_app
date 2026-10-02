import 'package:dony/features/matching/data/models/announcement_model.dart';

/// Une page de `GET /announcements` : les trajets et le total serveur, pour
/// que l'accueil affiche le même nombre que la recherche et charge la suite
/// (Sentry FLUTTER-6P/6Q : 20 trajets listés pour 22 annoncés).
class AnnouncementSearchPage {
  const AnnouncementSearchPage({
    required this.content,
    required this.totalElements,
    required this.page,
  });

  factory AnnouncementSearchPage.fromJson(
    Map<String, dynamic> json, {
    required int page,
  }) {
    final content = (json['content'] as List? ?? const [])
        .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return AnnouncementSearchPage(
      content: content,
      // Un back qui omettrait le total : on s'en tient à ce qui est chargé.
      totalElements: (json['totalElements'] as num?)?.toInt() ?? content.length,
      page: page,
    );
  }

  final List<AnnouncementModel> content;
  final int totalElements;
  final int page;
}
