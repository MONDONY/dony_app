import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';

/// Compte de versement mobile money du voyageur (Wave / Orange Money via
/// pawaPay). Distinct du paiement mobile money d'un bid côté expéditeur
/// (voir `matching/data/datasources/mobile_money_remote_datasource.dart`).
class MobileMoneyAccountRemoteDatasource {
  const MobileMoneyAccountRemoteDatasource(this._client);
  final ApiClient _client;

  Future<MobileMoneyAccount> get() async {
    final response = await _client.dio.get('/payments/mobile-money/account');
    return MobileMoneyAccount.fromJson(response.data as Map<String, dynamic>);
  }

  /// Réseaux utilisables pour le versement sur [phoneNumber] (sinon sur le
  /// numéro déjà enregistré côté back). POST : le numéro voyage dans le
  /// corps, jamais dans l'URL.
  Future<MobileMoneyProviderCatalog> providers({String? phoneNumber}) async {
    final response = phoneNumber != null
        ? await _client.dio.post(
            '/payments/mobile-money/providers',
            data: {'phoneNumber': phoneNumber},
          )
        : await _client.dio.post('/payments/mobile-money/providers');
    return MobileMoneyProviderCatalog.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// [phoneNumber] : numéro de versement saisi, prioritaire sur le numéro
  /// Firebase. [providers] : codes des réseaux acceptés ; vide, le back ne
  /// retient que l'opérateur prédit (ancien contrat). Aucun corps n'est
  /// envoyé quand les deux sont absents, pour ne rien changer au
  /// comportement historique.
  Future<MobileMoneyAccount> activate({
    String? phoneNumber,
    List<String> providers = const [],
  }) async {
    final body = <String, dynamic>{};
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;
    if (providers.isNotEmpty) body['providers'] = providers;
    final response = body.isEmpty
        ? await _client.dio.post('/payments/mobile-money/account')
        : await _client.dio.post('/payments/mobile-money/account', data: body);
    return MobileMoneyAccount.fromJson(response.data as Map<String, dynamic>);
  }

  /// Remplace les réseaux acceptés du compte actif, sans ressaisir le numéro.
  Future<MobileMoneyAccount> updateProviders(List<String> providers) async {
    final response = await _client.dio.put(
      '/payments/mobile-money/account/providers',
      data: {'providers': providers},
    );
    return MobileMoneyAccount.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MobileMoneyAccount> disable() async {
    final response = await _client.dio.delete('/payments/mobile-money/account');
    return MobileMoneyAccount.fromJson(response.data as Map<String, dynamic>);
  }
}
