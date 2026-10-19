import 'package:dony/core/network/api_client.dart';
import 'package:dony/core/pricing/commission_calculator.dart';
import 'package:dony/core/pricing/commission_grid_store.dart';

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

  Future<bool> getFlightsEnabled() async {
    final response = await _client.dio.get('/config/flights-enabled');
    final data = response.data as Map<String, dynamic>;
    return data['enabled'] as bool;
  }

  Future<bool> getProEnabled() async {
    final response = await _client.dio.get('/config/pro-enabled');
    final data = response.data as Map<String, dynamic>;
    return data['enabled'] as bool;
  }

  /// Grilles de commission par paliers : `{"current": GridView|null,
  /// "next": GridView|null}`. Un 404 (back sans la route) remonte en
  /// `DioException`, le repository le traduit en « pas de grille ».
  Future<CommissionGridConfig> getCommissionGrid() async {
    final response = await _client.dio.get('/config/commission-grid');
    return CommissionGridConfig.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  /// Grille figée d'une demande, par identifiant (404 si inconnue ou annulée).
  Future<CommissionGrid> getCommissionGridById(String id) async {
    final response = await _client.dio.get('/config/commission-grid/$id');
    return CommissionGrid.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
