import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';

class KycRepository {
  const KycRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<Map<String, dynamic>> createSession() async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/kyc/session',
      );
      if (response.data == null)
        throw const NetworkException(
          'Réponse invalide du serveur de vérification d\'identité',
        );
      return response.data!;
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/kyc/status',
      );
      if (response.data == null)
        throw const NetworkException(
          'Réponse invalide du serveur de vérification d\'identité',
        );
      return response.data!;
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<void> abandonSession() async {
    try {
      await _apiClient.dio.delete<void>('/kyc/session');
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
