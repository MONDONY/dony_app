import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/matching/data/models/mobile_money_payment_status.dart';
import 'package:dony/features/matching/data/models/mobile_money_scope.dart';
import 'package:dony/features/payments/data/models/mobile_money_provider_catalog.dart';

class MobileMoneyRemoteDatasource {
  const MobileMoneyRemoteDatasource(this._client);
  final ApiClient _client;

  Future<MobileMoneyPaymentStatus> getStatus(MobileMoneyScope scope) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      scope.statusPath,
    );
    return MobileMoneyPaymentStatus.fromJson(response.data!);
  }

  /// Réseaux avec lesquels l'expéditeur peut payer ce colis : ceux de son
  /// numéro ([phoneNumber], sinon celui du bid), restreints par le back aux
  /// marques acceptées par le voyageur. Liste vide = aucun réseau commun.
  Future<MobileMoneyProviderCatalog> providers(
    String bidId, {
    String? phoneNumber,
  }) async {
    final trimmed = phoneNumber?.trim();
    final body = (trimmed != null && trimmed.isNotEmpty)
        ? {'phoneNumber': trimmed}
        : null;
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/bids/$bidId/mobile-money/providers',
      data: body,
    );
    return MobileMoneyProviderCatalog.fromJson(response.data!);
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
