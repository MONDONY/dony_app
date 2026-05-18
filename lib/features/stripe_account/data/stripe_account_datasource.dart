import 'package:dony/core/models/connect_account_status.dart';
import 'package:dony/core/network/api_client.dart';

class StripeAccountDatasource {
  final ApiClient _client;

  StripeAccountDatasource(this._client);

  Future<ConnectAccountStatus> getAccountStatus() async {
    final response = await _client.dio.get('/payments/connect/account');
    return ConnectAccountStatus.fromJson(response.data as Map<String, dynamic>);
  }
}
