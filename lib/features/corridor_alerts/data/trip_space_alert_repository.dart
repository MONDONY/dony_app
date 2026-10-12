import 'package:dony/core/network/api_client.dart';

/// « Me prévenir si de la place se libère » sur un trajet complet
/// (FLUTTER-JH). Même module que les alertes de corridor, endpoints
/// distincts : l'abonnement porte sur UN trajet et se consomme à la première
/// notification.
class TripSpaceAlertRepository {
  const TripSpaceAlertRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Ids des trajets pour lesquels l'utilisateur attend une place.
  Future<Set<String>> getSubscribedTripIds() async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/me/trip-space-alerts',
    );
    return {
      for (final e in response.data ?? const <dynamic>[])
        if ((e as Map<String, dynamic>)['announcementId'] is String)
          e['announcementId'] as String,
    };
  }

  /// Idempotent côté serveur : renvoie l'abonnement déjà en attente.
  Future<void> subscribe(String announcementId) async {
    await _apiClient.dio.put<Map<String, dynamic>>(
      '/me/trip-space-alerts/$announcementId',
    );
  }

  Future<void> unsubscribe(String announcementId) async {
    await _apiClient.dio.delete<void>('/me/trip-space-alerts/$announcementId');
  }
}
