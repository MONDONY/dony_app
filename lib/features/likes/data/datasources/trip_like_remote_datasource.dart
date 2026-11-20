import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/likes/data/models/trip_like_status.dart';

class TripLikeRemoteDatasource {
  TripLikeRemoteDatasource(this._apiClient);

  final ApiClient _apiClient;

  /// `PUT /announcements/{id}/like`.
  Future<TripLikeStatus> like(String tripId) async {
    final res = await _apiClient.dio.put('/announcements/$tripId/like');
    return TripLikeStatus.fromJson(res.data as Map<String, dynamic>);
  }

  /// `DELETE /announcements/{id}/like`.
  Future<TripLikeStatus> unlike(String tripId) async {
    final res = await _apiClient.dio.delete('/announcements/$tripId/like');
    return TripLikeStatus.fromJson(res.data as Map<String, dynamic>);
  }
}
