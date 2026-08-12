import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/package_request/data/models/price_estimate.dart';

class PriceEstimationRepository {
  const PriceEstimationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PriceEstimate> estimate({
    required String from,
    required String to,
    required double weight,
    String currency = 'EUR',
  }) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/package-requests/estimate',
      queryParameters: {
        'from': from,
        'to': to,
        'weight': weight,
        'currency': currency,
      },
    );
    return PriceEstimate.fromJson(response.data!);
  }
}
