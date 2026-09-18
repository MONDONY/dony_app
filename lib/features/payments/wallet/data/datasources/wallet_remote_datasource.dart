import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_model.dart';

class WalletRemoteDatasource {
  final ApiClient _client;

  WalletRemoteDatasource(this._client);

  Future<WalletModel> getBalance() async {
    final response = await _client.dio.get('/wallet/balance');
    return WalletModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> topup({
    required double amount,
    required String paymentMethod,
    String currencyCode = 'EUR',
  }) async {
    final data = <String, dynamic>{
      'amount': double.parse(amount.toStringAsFixed(2)),
      'paymentMethod': paymentMethod,
    };
    if (currencyCode.toUpperCase() != 'EUR') {
      data['currencyCode'] = currencyCode.toUpperCase();
    }
    final response = await _client.dio.post('/wallet/topup', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getRefundEligibleTopups(String currency) async {
    final response = await _client.dio.get(
      '/wallet/${currency.toUpperCase()}/refund-eligible-topups',
    );
    return response.data as List<dynamic>;
  }

  /// Liste vide : corps omis, le back rembourse tout le remboursable de la
  /// devise (contrat depuis dony-back #302). Liste non vide : contrat
  /// historique de sélection par recharge, toujours accepté.
  Future<Map<String, dynamic>> requestRefund(
    String currency,
    List<String> transactionIds,
  ) async {
    final response = await _client.dio.post(
      '/wallet/${currency.toUpperCase()}/refund-request',
      data: transactionIds.isEmpty ? null : {'transactionIds': transactionIds},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getRefundRequests() async {
    final response = await _client.dio.get('/wallet/refund-requests');
    return response.data as List<dynamic>;
  }

  /// Réseaux mobile money utilisables pour payer une recharge depuis
  /// [phoneNumber]. Même contrat que
  /// `/payments/mobile-money/providers` : le numéro voyage dans le corps,
  /// jamais dans l'URL.
  Future<Map<String, dynamic>> topupProviders(String phoneNumber) async {
    final response = await _client.dio.post(
      '/wallet/topup/providers',
      data: {'phoneNumber': phoneNumber},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Initie une recharge mobile money. [provider] omis quand nul : sans lui,
  /// l'opérateur prédit par pawaPay pour ce numéro s'applique.
  Future<Map<String, dynamic>> topupMobileMoney({
    required double amount,
    required String phoneNumber,
    String? provider,
  }) async {
    final data = <String, dynamic>{
      'amount': double.parse(amount.toStringAsFixed(2)),
      'paymentMethod': 'MOBILE_MONEY',
      'phoneNumber': phoneNumber,
    };
    if (provider != null) {
      data['provider'] = provider;
    }
    final response = await _client.dio.post('/wallet/topup', data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Statut d'une recharge mobile money, relu en boucle pendant l'attente du
  /// PIN opérateur.
  Future<Map<String, dynamic>> topupStatus(String topupId) async {
    final response = await _client.dio.get('/wallet/topup/$topupId/status');
    return response.data as Map<String, dynamic>;
  }
}
