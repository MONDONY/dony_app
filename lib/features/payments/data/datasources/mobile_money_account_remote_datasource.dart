import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/payments/data/models/mobile_money_account.dart';

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

  /// [phoneNumber] : numéro mobile money saisi par le voyageur, à envoyer
  /// seulement quand son compte Firebase n'a pas de téléphone (vérification
  /// SMS Twilio pas encore configurée). Le backend l'ignore si le compte a
  /// déjà un numéro vérifié — aucun corps n'est envoyé quand il est nul, pour
  /// ne rien changer au comportement historique.
  Future<MobileMoneyAccount> activate({String? phoneNumber}) async {
    final response = phoneNumber != null
        ? await _client.dio.post(
            '/payments/mobile-money/account',
            data: {'phoneNumber': phoneNumber},
          )
        : await _client.dio.post('/payments/mobile-money/account');
    return MobileMoneyAccount.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MobileMoneyAccount> disable() async {
    final response = await _client.dio.delete('/payments/mobile-money/account');
    return MobileMoneyAccount.fromJson(response.data as Map<String, dynamic>);
  }
}
