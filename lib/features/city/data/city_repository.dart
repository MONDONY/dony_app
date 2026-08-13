import 'package:dony/features/city/data/city_datasource.dart';
import 'package:dony/features/city/data/city_model.dart';
import 'package:dony/features/city/data/popular_corridor_model.dart';

class CityRepository {
  const CityRepository({required CityDatasource datasource})
    : _datasource = datasource;

  final CityDatasource _datasource;

  Future<List<CityModel>> searchCities(String query) =>
      _datasource.searchCities(query);

  Future<List<PopularCorridorModel>> getPopularCorridors() =>
      _datasource.getPopularCorridors();
}
