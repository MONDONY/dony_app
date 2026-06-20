import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/corridor_alerts/data/models/alert_direction.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_matches.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:dony/features/corridor_alerts/data/models/trip_match_model.dart';
import 'package:dony/features/package_request/data/models/matching_request.dart';

class CorridorAlertRepository {
  const CorridorAlertRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CorridorAlertModel>> getMyAlerts({
    AlertDirection? direction,
  }) async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/me/corridor-alerts',
      queryParameters: {
        if (direction != null) 'direction': direction.wire,
      },
    );
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

  /// Matchs pour une alerte. Selon [direction], retourne soit une liste de
  /// [MatchingRequestModel] (colis, direction TRAVELER_WANTS_PACKAGES) soit
  /// une liste de [TripMatchModel] (trajets, direction SENDER_WANTS_TRIPS).
  Future<CorridorAlertMatches> getMatches(
    String id,
    AlertDirection direction,
  ) async {
    final response = await _apiClient.dio
        .get<List<dynamic>>('/me/corridor-alerts/$id/matches');
    final raw = response.data ?? <dynamic>[];
    if (direction == AlertDirection.senderWantsTrips) {
      return CorridorAlertMatches(
        direction: direction,
        trips: raw
            .map((e) => TripMatchModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    }
    return CorridorAlertMatches(
      direction: direction,
      packages: raw
          .map((e) => MatchingRequestModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
