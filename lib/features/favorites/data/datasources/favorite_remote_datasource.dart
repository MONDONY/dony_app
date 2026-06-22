import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/favorites/data/models/favorite_ids.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';

class FavoriteRemoteDatasource {
  final ApiClient _apiClient;

  FavoriteRemoteDatasource(this._apiClient);

  /// Add a favorite. [type] ∈ { 'trip', 'package-request' }.
  Future<void> add(String type, String id) =>
      _apiClient.dio.put('/favorites/$type/$id');

  /// Remove a favorite. [type] ∈ { 'trip', 'package-request' }.
  Future<void> remove(String type, String id) =>
      _apiClient.dio.delete('/favorites/$type/$id');

  /// Returns the current user's favorited trip and package-request IDs.
  Future<FavoriteIds> ids() async {
    final res = await _apiClient.dio.get('/favorites/ids');
    return FavoriteIds.fromJson(res.data as Map<String, dynamic>);
  }

  /// Returns the favorited trip announcements (full search-item shape).
  Future<List<AnnouncementModel>> trips() async {
    final res = await _apiClient.dio.get('/favorites/trips');
    return (res.data as List)
        .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns the favorited package-request items.
  Future<List<PackageRequestSearchItem>> packageRequests() async {
    final res = await _apiClient.dio.get('/favorites/package-requests');
    return (res.data as List)
        .map((e) =>
            PackageRequestSearchItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
