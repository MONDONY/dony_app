import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/cancellation/data/models/cancellation_model.dart';

class CancellationRemoteDatasource {
  final ApiClient _apiClient;

  CancellationRemoteDatasource(this._apiClient);

  Future<CancellationModel> cancelTrip({
    required String announcementId,
    required String reason,
  }) async {
    final response = await _apiClient.dio.post('/cancellations', data: {
      'announcementId': announcementId,
      'reason': reason,
    });
    return CancellationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<RematchSuggestionModel>> getRematchSuggestions(String cancellationId) async {
    final response = await _apiClient.dio.get('/cancellations/$cancellationId/rematch-suggestions');
    return (response.data as List)
        .map((s) => RematchSuggestionModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }
}
