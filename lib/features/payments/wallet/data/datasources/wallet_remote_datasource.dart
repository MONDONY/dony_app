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

  Future<Map<String, dynamic>> requestRefund(String currency) async {
    final response = await _client.dio.post(
      '/wallet/${currency.toUpperCase()}/refund-request',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getRefundRequests() async {
    final response = await _client.dio.get('/wallet/refund-requests');
    return response.data as List<dynamic>;
  }
}
