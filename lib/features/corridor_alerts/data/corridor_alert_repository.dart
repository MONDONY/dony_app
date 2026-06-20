import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/package_request/data/models/matching_request.dart';

class CorridorAlertRepository {
  const CorridorAlertRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CorridorAlertModel>> getMyAlerts() async {
    final response =
        await _apiClient.dio.get<List<dynamic>>('/me/corridor-alerts');
    return (response.data ?? <dynamic>[])
        .map((e) => CorridorAlertModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CorridorAlertModel> create(CorridorAlertDraft draft) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/me/corridor-alerts',
      data: draft.toJson(),
    );
    return CorridorAlertModel.fromJson(response.data!);
  }

  Future<CorridorAlertModel> update(
    String id,
    CorridorAlertDraft draft, {
    bool? active,
  }) async {
    final body = draft.toJson();
    if (active != null) {
      body['active'] = active;
    }
    final response = await _apiClient.dio.put<Map<String, dynamic>>(
      '/me/corridor-alerts/$id',
      data: body,
    );
    return CorridorAlertModel.fromJson(response.data!);
  }

  Future<void> delete(String id) async {
    await _apiClient.dio.delete<void>('/me/corridor-alerts/$id');
  }

  /// Colis OPEN matchant l'alerte (tap sur la carte).
  Future<List<MatchingRequestModel>> getMatches(String id) async {
    final response = await _apiClient.dio
        .get<List<dynamic>>('/me/corridor-alerts/$id/matches');
    return (response.data ?? <dynamic>[])
        .map((e) => MatchingRequestModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
