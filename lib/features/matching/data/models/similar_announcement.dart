import 'package:dony/features/matching/data/models/announcement_model.dart';

/// Un critère de recherche qu'un trajet proche ne remplit pas (bloc « autres
/// annonces » de `GET /announcements`). [code] reste une chaîne : un code
/// inconnu d'une version plus récente du back doit traverser sans casser.
class UnmetCriterion {
  const UnmetCriterion({
    required this.code,
    this.requested = '',
    this.actual = '',
  });

  factory UnmetCriterion.fromJson(Map<String, dynamic> json) => UnmetCriterion(
    code: json['code'] as String,
    requested: json['requested'] as String? ?? '',
    actual: json['actual'] as String? ?? '',
  );

  final String code;
  final String requested;
  final String actual;
}

/// Un trajet qui ne répond pas à tous les critères, avec ceux qui manquent.
class SimilarAnnouncement {
  const SimilarAnnouncement({required this.announcement, required this.unmet});

  factory SimilarAnnouncement.fromJson(Map<String, dynamic> json) =>
      SimilarAnnouncement(
        announcement: AnnouncementModel.fromJson(
          json['announcement'] as Map<String, dynamic>,
        ),
        unmet: (json['unmet'] as List? ?? const [])
            .map((e) => UnmetCriterion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final AnnouncementModel announcement;
  final List<UnmetCriterion> unmet;
}
