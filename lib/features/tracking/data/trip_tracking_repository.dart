import 'package:dony/core/network/api_client.dart';

/// Suivi approximatif du voyageur : envoi de sa position et départ.
/// « Je suis arrivé » passe par `AnnouncementRepository.markTripArrived`
/// (paramètre facultatif `position`).
///
/// Les coordonnées ne sont jamais journalisées ici.
class TripTrackingRepository {
  TripTrackingRepository(this._apiClient);

  final ApiClient _apiClient;

  /// `POST /announcements/{id}/position`. Le back répond 200 même s'il ne
  /// retient rien (fenêtre fermée, limite de 15 min, pas de ville).
  Future<void> sendPosition(
    String announcementId,
    double lat,
    double lon,
  ) async {
    await _apiClient.dio.post(
      '/announcements/$announcementId/position',
      data: {'lat': lat, 'lon': lon},
    );
  }

  /// `POST /announcements/{id}/depart`, corps vide sans position.
  Future<void> depart(String announcementId, {double? lat, double? lon}) async {
    final hasPosition = lat != null && lon != null;
    await _apiClient.dio.post(
      '/announcements/$announcementId/depart',
      data: hasPosition ? {'lat': lat, 'lon': lon} : null,
    );
  }
}
