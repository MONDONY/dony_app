import 'package:dony/core/network/api_client.dart';

class KycRepository {
  const KycRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<Map<String, dynamic>> createSession() async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>('/kyc/session');
    if (response.data == null) {
      throw Exception('Réponse invalide du serveur KYC');
    }
    return response.data!;
  }

  Future<Map<String, dynamic>> getStatus() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>('/kyc/status');
    if (response.data == null) {
      throw Exception('Réponse invalide du serveur KYC');
    }
    return response.data!;
  }
}
