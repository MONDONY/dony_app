import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';

/// Appels de l'app aux modals vidéo (`/video-modals/...`).
///
/// Un échec est attendu tant que le back n'est pas déployé (404) : jamais
/// rapporté à Sentry, jamais rejoué. Le dépôt l'avale.
class VideoModalRemoteDatasource {
  VideoModalRemoteDatasource(this._client);

  final ApiClient _client;

  static Options get _quiet => Options(
    extra: const {
      ApiClient.skipErrorReportKey: true,
      'skipTransientRetry': true,
    },
  );

  /// Capacités de cette app : formats et images (`layout`), ciblage et
  /// fréquences (`targeting`), moments d'action (`moments`). Un back ancien
  /// ignore le paramètre.
  static const caps = 'layout,targeting,moments';

  /// `GET /video-modals/eligible?lang=&caps=&appVersion=&platform=` : public,
  /// le jeton est facultatif. [appVersion] (`x.y.z`) et [platform]
  /// (`android` / `ios`) servent au ciblage du back ; `appVersion` est omise
  /// quand l'app ne sait pas la lire.
  Future<Object?> fetchEligible(
    String lang, {
    String? appVersion,
    String? platform,
  }) async {
    final response = await _client.dio.get<Object?>(
      '/video-modals/eligible',
      queryParameters: {
        'lang': lang,
        'caps': caps,
        'appVersion': ?appVersion,
        'platform': ?platform,
      },
      options: _quiet,
    );
    return response.data;
  }

  /// `POST /video-modals/{id}/events` (204).
  Future<void> postEvent(
    String campaignId, {
    required int version,
    required String event,
    DateTime? occurredAt,
  }) async {
    await _client.dio.post<Object?>(
      '/video-modals/$campaignId/events',
      data: {
        'version': version,
        'event': event,
        if (occurredAt != null)
          'occurredAt': occurredAt.toUtc().toIso8601String(),
      },
      options: _quiet,
    );
  }
}
