import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/network/api_client.dart';

class StripeAccountDatasource {
  final ApiClient _client;

  StripeAccountDatasource(this._client);

  /// Lit le statut tel qu'il est stocké côté serveur. Aucun appel à Stripe :
  /// la valeur peut dater du dernier webhook reçu.
  Future<ConnectAccountStatus> getAccountStatus() async {
    final response = await _client.dio.get('/payments/connect/account');
    return ConnectAccountStatus.fromJson(response.data as Map<String, dynamic>);
  }

  /// Force le serveur à réinterroger Stripe et à réenregistrer le statut.
  ///
  /// Le seul autre mécanisme de mise à jour est le webhook `account.updated` :
  /// s'il est manqué (serveur indisponible, tunnel de dev fermé), le statut
  /// stocké reste faux indéfiniment et l'utilisateur se retrouve bloqué sur un
  /// écran qui ne correspond plus à la réalité de son compte.
  ///
  /// Renvoie 409 `stripe-account-required` si l'utilisateur n'a aucun compte
  /// Stripe — cas normal, à traiter comme un non-événement par l'appelant.
  Future<ConnectAccountStatus> refreshAccountStatus() async {
    final response = await _client.dio.post('/payments/connect/refresh');
    return ConnectAccountStatus.fromJson(response.data as Map<String, dynamic>);
  }
}
