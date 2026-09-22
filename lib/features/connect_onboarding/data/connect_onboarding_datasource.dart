import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/network/api_client.dart';

class ConnectOnboardingDatasource {
  final ApiClient _client;

  ConnectOnboardingDatasource(this._client);

  Future<ConnectAccountStatus> getAccountStatus() async {
    final response = await _client.dio.get('/payments/connect/account');
    final data = response.data as Map<String, dynamic>;
    return ConnectAccountStatus.fromJson(data);
  }

  /// Crée le compte Stripe Connect, ou renvoie celui qui existe déjà.
  ///
  /// Le serveur est idempotent : il vérifie le compte existant auprès de
  /// Stripe et n'en provisionne un nouveau que s'il n'y en a pas (ou si
  /// l'ancien a disparu).
  Future<ConnectAccountStatus> createConnectAccount() async {
    final response = await _client.dio.post('/payments/connect/account');
    final data = response.data as Map<String, dynamic>;
    return ConnectAccountStatus.fromJson(data);
  }

  Future<String> createOnboardingLink() async {
    final response = await _client.dio.post(
      '/payments/connect/onboarding-link',
    );
    final data = response.data as Map<String, dynamic>;
    return data['url'] as String;
  }
}
