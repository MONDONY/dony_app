import 'package:dony/core/network/api_client.dart';

class ConfigDatasource {
  final ApiClient _client;

  ConfigDatasource(this._client);

  Future<double> getCommissionRate() async {
    final response = await _client.dio.get('/config/commission-rate');
    final data = response.data as Map<String, dynamic>;
    return (data['rate'] as num).toDouble();
  }
}
