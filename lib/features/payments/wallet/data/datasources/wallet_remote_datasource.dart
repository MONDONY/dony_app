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
    String? countryCode,
    String? phoneNumber,
  }) async {
    final body = <String, dynamic>{
      'amount': double.parse(amount.toStringAsFixed(2)),
      'paymentMethod': paymentMethod,
    };
    if (countryCode != null) body['countryCode'] = countryCode;
    if (phoneNumber != null) body['phoneNumber'] = phoneNumber;

    final response = await _client.dio.post('/wallet/topup', data: body);
    return response.data as Map<String, dynamic>;
  }
}
