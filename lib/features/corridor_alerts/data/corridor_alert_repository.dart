import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';

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

  Future<CorridorAlertModel> update(String id, CorridorAlertDraft draft) async {
    final response = await _apiClient.dio.put<Map<String, dynamic>>(
      '/me/corridor-alerts/$id',
      data: draft.toJson(),
    );
    return CorridorAlertModel.fromJson(response.data!);
  }

  Future<void> delete(String id) async {
    await _apiClient.dio.delete<void>('/me/corridor-alerts/$id');
  }

  /// Colis OPEN matchant l'alerte (tap sur la carte). Le type de retour est
  /// affiné en `List<MatchingRequestModel>` en Task 2 ; ici renvoie les maps
  /// bruts pour ne pas créer de dépendance de tâche inversée.
  Future<List<Map<String, dynamic>>> getMatches(String id) async {
    final response = await _apiClient.dio
        .get<List<dynamic>>('/me/corridor-alerts/$id/matches');
    return (response.data ?? <dynamic>[])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }
}
