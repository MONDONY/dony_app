import 'package:dony/features/favorites/data/datasources/favorite_remote_datasource.dart';
import 'package:dony/features/favorites/data/models/favorite_ids.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';

class FavoriteRepository {
  final FavoriteRemoteDatasource _datasource;

  FavoriteRepository(this._datasource);

  /// Add a favorite. [type] ∈ { 'trip', 'package-request' }.
  Future<void> add(String type, String id) => _datasource.add(type, id);

  /// Remove a favorite. [type] ∈ { 'trip', 'package-request' }.
  Future<void> remove(String type, String id) => _datasource.remove(type, id);

  /// Returns the current user's favorited trip and package-request IDs.
  Future<FavoriteIds> ids() => _datasource.ids();

  /// Returns the favorited trip announcements.
  Future<List<AnnouncementModel>> trips() => _datasource.trips();

  /// Returns the favorited package-request items.
  Future<List<PackageRequestSearchItem>> packageRequests() =>
      _datasource.packageRequests();
}
