import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/activation/data/models/activation_status.dart';

/// Guidage après KYC : statut d'activation et intention (`/users/me`).
class ActivationRepository {
  const ActivationRepository(this._apiClient);

  final ApiClient _apiClient;

  /// `null` quand le backend ne connaît pas encore l'endpoint (404) : l'app
  /// garde le parcours historique tant que la prod backend n'est pas déployée.
  Future<ActivationStatus?> fetch() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/users/me/activation',
      );
      return ActivationStatus.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> declareIntent({
    required UserIntent intent,
    required String? destinationCountry,
    required IntentSource source,
  }) async {
    await _apiClient.dio.put<dynamic>(
      '/users/me/intent',
      data: {
        'intent': intent.wire,
        'destinationCountry': destinationCountry,
        'source': source.wire,
      },
    );
  }
}
