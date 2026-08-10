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

  /// Idempotent côté backend — retourne le compte existant s'il y en a déjà un.
  //
  // Body explicite obligatoire : un POST sans `data` laisse dart:io choisir
  // l'encodage (chunked, sans Content-Length) et sur certains devices la
  // requête ne se termine jamais côté client — ni connectTimeout ni
  // sendTimeout ne s'en aperçoivent puisque rien ne signale d'erreur, elle
  // reste simplement ouverte indéfiniment. Un body connu fixe le
  // Content-Length et évite ce mode.
  Future<ConnectAccountStatus> createAccount() async {
    final response = await _client.dio.post(
      '/payments/connect/account',
      data: <String, dynamic>{},
    );
    final data = response.data as Map<String, dynamic>;
    return ConnectAccountStatus.fromJson(data);
  }

  Future<String> createOnboardingLink() async {
    final response = await _client.dio.post(
      '/payments/connect/onboarding-link',
      data: <String, dynamic>{},
    );
    final data = response.data as Map<String, dynamic>;
    return data['url'] as String;
  }
}
