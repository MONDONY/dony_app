import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/mobile_money_accepted_operators.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';

class MobileMoneyRemoteDatasource {
  const MobileMoneyRemoteDatasource(this._client);
  final ApiClient _client;

  Future<MobileMoneyPaymentStatus> getStatus(MobileMoneyScope scope) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      scope.statusPath,
    );
    return MobileMoneyPaymentStatus.fromJson(response.data!);
  }

  /// Opérateurs que le voyageur accepte pour ce colis, ce fil ou ce
  /// supplément. Un ancien back répond 404 (route absente) : le dépôt
  /// ([MobileMoneyRepository.acceptedOperators]) le traduit en `null`.
  Future<MobileMoneyAcceptedOperators> acceptedOperators(
    MobileMoneyScope scope,
  ) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      scope.acceptedOperatorsPath,
    );
    return MobileMoneyAcceptedOperators.fromJson(response.data!);
  }

  /// Initie (ou relance) une tentative de paiement mobile money. Le numéro
  /// n'est envoyé que s'il est non vide après `trim()` : sans numéro, le
  /// backend réutilise le dernier numéro connu du bid ou du fil. [provider]
  /// est le code de l'opérateur choisi par le payeur (sans lui, le back
  /// applique l'opérateur prédit) ; envoyé lui aussi seulement non vide après
  /// `trim()`. Numéro et opérateur ne vont jamais dans une URL ni un log.
  Future<MobileMoneyPaymentStatus> initiate(
    MobileMoneyScope scope, {
    String? phoneNumber,
    String? provider,
  }) async {
    final trimmedPhone = phoneNumber?.trim();
    final trimmedProvider = provider?.trim();
    final body = <String, dynamic>{};
    if (trimmedPhone != null && trimmedPhone.isNotEmpty) {
      body['phoneNumber'] = trimmedPhone;
    }
    if (trimmedProvider != null && trimmedProvider.isNotEmpty) {
      body['provider'] = trimmedProvider;
    }
    final response = await _client.dio.post<Map<String, dynamic>>(
      scope.initiatePath,
      data: body.isEmpty ? null : body,
    );
    return MobileMoneyPaymentStatus.fromJson(response.data!);
  }
}
