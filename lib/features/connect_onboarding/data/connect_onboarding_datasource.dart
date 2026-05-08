import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/connect_onboarding/data/connect_onboarding_repository.dart';

class ConnectOnboardingDatasource {
  final ApiClient _client;

  ConnectOnboardingDatasource(this._client);

  Future<ConnectAccountStatus> getAccountStatus() async {
    final response = await _client.dio.get('/payments/connect/account');
    final data = response.data as Map<String, dynamic>;
    return ConnectAccountStatus.fromJson(data);
  }

  Future<String> createOnboardingLink() async {
    final response = await _client.dio.post('/payments/connect/onboarding-link');
    final data = response.data as Map<String, dynamic>;
    return data['url'] as String;
  }
}
