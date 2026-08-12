import 'city_datasource.dart';
import 'city_model.dart';
import 'popular_corridor_model.dart';

class CityRepository {
  const CityRepository({required CityDatasource datasource})
      : _datasource = datasource;

  final CityDatasource _datasource;

  Future<List<CityModel>> searchCities(String query) =>
      _datasource.searchCities(query);

  Future<List<PopularCorridorModel>> getPopularCorridors() =>
      _datasource.getPopularCorridors();
}
