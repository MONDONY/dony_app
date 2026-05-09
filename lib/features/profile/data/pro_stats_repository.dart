import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/profile/data/models/pro_stats_model.dart';

class ProStatsRepository {
  final ApiClient _client;

  ProStatsRepository(this._client);

  Future<ProStatsModel> fetchStats() async {
    try {
      final response = await _client.dio.get('/travelers/me/stats');
      return ProStatsModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
