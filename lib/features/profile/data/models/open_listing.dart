import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';

/// Annonce ouverte d'un membre, pour la section « En cours » de son profil :
/// un trajet ou une demande d'envoi, dans le format de la recherche.
///
/// Servie par `GET /users/{id}/open-listings` (yadony-back #645), déjà triée
/// de la plus récente à la plus ancienne publication.
sealed class OpenListing {
  const OpenListing({required this.publishedAt});

  /// Date de publication, clé de tri de la liste.
  final DateTime publishedAt;

  /// Lit un élément de la réponse. Rend `null` pour un `kind` inconnu (un back
  /// plus récent que l'app) : l'élément est simplement ignoré.
  static OpenListing? fromJson(Map<String, dynamic> json) {
    final publishedAt = _parseUtc(json['publishedAt'] as String);
    switch (json['kind']) {
      case 'TRIP':
        return OpenTripListing(
          announcement: AnnouncementModel.fromJson(
            json['trip'] as Map<String, dynamic>,
          ),
          publishedAt: publishedAt,
        );
      case 'REQUEST':
        return OpenRequestListing(
          item: PackageRequestSearchItem.fromJson(
            json['request'] as Map<String, dynamic>,
          ),
          publishedAt: publishedAt,
        );
      default:
        return null;
    }
  }
}

/// Le back sérialise un `LocalDateTime` en UTC sans suffixe de fuseau : sans le
/// `Z`, `DateTime.parse` le lirait en heure locale et décalerait « hier ».
DateTime _parseUtc(String raw) =>
    DateTime.parse(raw.endsWith('Z') || raw.contains('+') ? raw : '${raw}Z');

class OpenTripListing extends OpenListing {
  const OpenTripListing({
    required this.announcement,
    required super.publishedAt,
  });

  final AnnouncementModel announcement;
}

class OpenRequestListing extends OpenListing {
  const OpenRequestListing({required this.item, required super.publishedAt});

  final PackageRequestSearchItem item;
}
