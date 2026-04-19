import 'package:dony/core/network/api_client.dart';

class KycRepository {
  const KycRepository(this._apiClient);
  final ApiClient _apiClient;

  Future<Map<String, dynamic>> createSession() async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>('/kyc/session');
    return response.data!;
  }

  Future<Map<String, dynamic>> getStatus() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>('/kyc/status');
    return response.data!;
  }
}
