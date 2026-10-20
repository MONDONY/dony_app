import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';
import 'package:dony/features/payments/data/models/mobile_money_countries.dart';
import 'package:dony/features/payments/data/models/mobile_money_payout_account.dart';
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

  /// Réseaux utilisables pour le versement sur [phoneNumber]. POST : le
  /// numéro voyage dans le corps, jamais dans l'URL.
  Future<MobileMoneyProviderCatalog> providers({
    required String phoneNumber,
  }) async {
    final response = await _client.dio.post(
      '/payments/mobile-money/providers',
      data: {'phoneNumber': phoneNumber},
    );
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

  Future<MobileMoneyAccount> disable() async {
    final response = await _client.dio.delete('/payments/mobile-money/account');
    return MobileMoneyAccount.fromJson(response.data as Map<String, dynamic>);
  }

  // --- Plusieurs comptes de versement (un par code opérateur) ---

  /// Comptes de versement et réseaux suggérés. 404 sur un back ancien.
  Future<MobileMoneyPayoutAccounts> accounts() async {
    final response = await _client.dio.get('/payments/mobile-money/accounts');
    return MobileMoneyPayoutAccounts.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Ajoute un compte pour [provider]. Le numéro voyage dans le corps.
  Future<MobileMoneyPayoutAccount> addAccount({
    required String phoneNumber,
    required String provider,
  }) async {
    final response = await _client.dio.post(
      '/payments/mobile-money/accounts',
      data: {'phoneNumber': phoneNumber, 'provider': provider},
    );
    return MobileMoneyPayoutAccount.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Change le numéro du compte [id] (409 `mobile-money-account-locked`
  /// tant qu'un versement attend).
  Future<MobileMoneyPayoutAccount> changeNumber({
    required String id,
    required String phoneNumber,
  }) async {
    final response = await _client.dio.put(
      '/payments/mobile-money/accounts/$id/number',
      data: {'phoneNumber': phoneNumber},
    );
    return MobileMoneyPayoutAccount.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  /// Retire le compte [id] (204, sans corps).
  Future<void> removeAccount(String id) async {
    await _client.dio.delete('/payments/mobile-money/accounts/$id');
  }

  /// Pays et réseaux où un versement est possible.
  Future<MobileMoneyCountries> payoutCountries() async {
    final response = await _client.dio.get(
      '/payments/mobile-money/countries',
      queryParameters: {'operation': 'PAYOUT'},
    );
    return MobileMoneyCountries.fromJson(response.data as Map<String, dynamic>);
  }
}
