import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';

class MoneyRemoteDatasource {
  MoneyRemoteDatasource(this._client);

  final ApiClient _client;

  Future<MoneyOverviewModel> getOverview() async {
    final response = await _client.dio.get('/payments/me/overview');
    return MoneyOverviewModel.fromJson(response.data as Map<String, dynamic>);
  }
}
