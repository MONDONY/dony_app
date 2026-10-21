import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/similar_announcement.dart';

/// Une page de `GET /announcements` : les trajets et le total serveur, pour
/// que l'accueil affiche le même nombre que la recherche et charge la suite
/// (Sentry FLUTTER-6P/6Q : 20 trajets listés pour 22 annoncés).
class AnnouncementSearchPage {
  const AnnouncementSearchPage({
    required this.content,
    required this.totalElements,
    required this.page,
    this.bookableElements,
    this.similar = const [],
  });

  factory AnnouncementSearchPage.fromJson(
    Map<String, dynamic> json, {
    required int page,
  }) {
    final content = (json['content'] as List? ?? const [])
        .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final similar = <SimilarAnnouncement>[];
    for (final e in json['similarAnnouncements'] as List? ?? const []) {
      try {
        similar.add(SimilarAnnouncement.fromJson(e as Map<String, dynamic>));
      } on Object {
        // Entrée illisible : on l'ignore, le reste de la page reste utile.
      }
    }
    return AnnouncementSearchPage(
      content: content,
      // Un back qui omettrait le total : on s'en tient à ce qui est chargé.
      totalElements: (json['totalElements'] as num?)?.toInt() ?? content.length,
      page: page,
      bookableElements: (json['bookableElements'] as num?)?.toInt(),
      similar: similar,
    );
  }

  final List<AnnouncementModel> content;
  final int totalElements;
  final int page;

  /// Trajets réservables seuls, quand la page inclut aussi les complets
  /// (FLUTTER-JH). [totalElements] compte alors les deux, pour paginer
  /// jusqu'au bout ; ce nombre-ci alimente le compteur « N trajets ». `null`
  /// sur un back antérieur, qui ne renvoie que des réservables.
  final int? bookableElements;

  /// Trajets proches qui manquent un critère (bloc « autres annonces »), avec
  /// les critères non remplis. Vide sur un back antérieur ou sans recherche.
  final List<SimilarAnnouncement> similar;
}
