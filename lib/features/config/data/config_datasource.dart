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

  /// Taux administrés courants : `{"rates":[{"currency":"USD","unitsPerEur":1.16},...]}`.
  Future<Map<String, double>> getExchangeRates() async {
    final response = await _client.dio.get('/config/exchange-rates');
    final data = response.data as Map<String, dynamic>;
    final rates = data['rates'] as List<dynamic>;
    return {
      for (final entry in rates.cast<Map<String, dynamic>>())
        entry['currency'] as String: (entry['unitsPerEur'] as num).toDouble(),
    };
  }

  Future<bool> getProEnabled() async {
    final response = await _client.dio.get('/config/pro-enabled');
    final data = response.data as Map<String, dynamic>;
    return data['enabled'] as bool;
  }
}
