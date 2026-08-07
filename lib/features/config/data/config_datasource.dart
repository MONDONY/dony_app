import 'package:dony/core/network/api_client.dart';

class ConfigDatasource {
  final ApiClient _client;

  ConfigDatasource(this._client);

  Future<double> getCommissionRate() async {
    final response = await _client.dio.get('/config/commission-rate');
    final data = response.data as Map<String, dynamic>;
    return (data['rate'] as num).toDouble();
  }

  Future<int> getUrgencyThresholdDays() async {
    final response = await _client.dio.get('/config/urgency-threshold');
    final data = response.data as Map<String, dynamic>;
    return (data['thresholdDays'] as num).toInt();
  }

  Future<double> getReimbursementCap() async {
    final response = await _client.dio.get('/config/reimbursement-cap');
    final data = response.data as Map<String, dynamic>;
    return (data['maxAmountEur'] as num).toDouble();
  }

  Future<bool> getSmsEnabled() async {
    final response = await _client.dio.get('/config/sms-enabled');
    final data = response.data as Map<String, dynamic>;
    return data['enabled'] as bool;
  }
}
