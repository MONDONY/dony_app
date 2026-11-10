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

  /// `GET /video-modals/eligible?lang=` : public, le jeton est facultatif.
  Future<Object?> fetchEligible(String lang) async {
    final response = await _client.dio.get<Object?>(
      '/video-modals/eligible',
      queryParameters: {'lang': lang},
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
