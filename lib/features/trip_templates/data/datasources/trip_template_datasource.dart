import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/trip_templates/data/models/trip_template.dart';

class TripTemplateDatasource {
  final ApiClient _apiClient;

  TripTemplateDatasource(this._apiClient);

  Future<List<TripTemplate>> getAll() async {
    final response = await _apiClient.dio.get('/trip-templates');
    return (response.data as List)
        .map((j) => TripTemplate.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<TripTemplate> create(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post('/trip-templates', data: data);
    return TripTemplate.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TripTemplate> update(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.dio.put('/trip-templates/$id', data: data);
    return TripTemplate.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _apiClient.dio.delete('/trip-templates/$id');
  }
}
