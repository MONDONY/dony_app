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
  }) async {
    final response = await _client.dio.post(
      '/wallet/topup',
      data: {'amount': amount, 'paymentMethod': paymentMethod},
    );
    return response.data as Map<String, dynamic>;
  }
}
