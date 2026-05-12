import 'package:dony/features/favorite_travelers/data/datasources/favorite_traveler_datasource.dart';
import 'package:dony/features/favorite_travelers/data/models/favorite_traveler.dart';

class FavoriteTravelerRepository {
  final FavoriteTravelerDatasource _datasource;

  FavoriteTravelerRepository(this._datasource);

  Future<List<FavoriteTraveler>> getAll() => _datasource.getAll();

  Future<void> remove(String travelerId) => _datasource.remove(travelerId);
}
