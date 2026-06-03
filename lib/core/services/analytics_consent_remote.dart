import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/services/analytics_service.dart';

/// Implémentation HTTP (Dio) de [AnalyticsConsentRemote].
///
/// Frappe les endpoints `GET`/`PUT /auth/me/analytics-consent` (l'utilisateur
/// est résolu côté backend via le token Firebase — jamais d'ID arbitraire).
/// Le Dio est gardé hors de `analytics_service.dart` pour éviter d'y faire
/// dépendre le service de tracking d'`ApiClient`/Dio.
class ApiAnalyticsConsentRemote implements AnalyticsConsentRemote {
  const ApiAnalyticsConsentRemote(this._api);

  final ApiClient _api;

  @override
  Future<bool?> fetch() async {
    final resp = await _api.dio.get('/auth/me/analytics-consent');
    final data = resp.data;
    return data is Map ? data['granted'] as bool? : null;
  }

  @override
  Future<void> push({
    required bool granted,
    required String policyVersion,
    required String source,
  }) async {
    await _api.dio.put(
      '/auth/me/analytics-consent',
      data: {
        'granted': granted,
        'policyVersion': policyVersion,
        'source': source,
      },
    );
  }
}
