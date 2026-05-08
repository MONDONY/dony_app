import 'package:dio/dio.dart';
import 'city_model.dart';
import 'popular_corridor_model.dart';

class CityDatasource {
  const CityDatasource({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<CityModel>> searchCities(String query) async {
    final response = await _dio.get<dynamic>(
      '/cities/search',
      queryParameters: {'q': query, 'limit': 10},
    );
    return ((response.data as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .map(CityModel.fromJson)
        .toList();
  }

  Future<List<PopularCorridorModel>> getPopularCorridors() async {
    final response = await _dio.get<dynamic>(
      '/cities/corridors/popular',
      queryParameters: {'limit': 6},
    );
    return ((response.data as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .map(PopularCorridorModel.fromJson)
        .toList();
  }
}
