import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/trip_templates/data/models/trip_recurrence.dart';

class TripRecurrenceDatasource {
  final ApiClient _apiClient;

  TripRecurrenceDatasource(this._apiClient);

  Future<List<TripRecurrence>> getAll() async {
    final response = await _apiClient.dio.get('/trip-recurrences');
    return (response.data as List)
        .map((j) => TripRecurrence.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<TripRecurrence> create(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post('/trip-recurrences', data: data);
    return TripRecurrence.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TripRecurrence> update(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.dio.put(
      '/trip-recurrences/$id',
      data: data,
    );
    return TripRecurrence.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _apiClient.dio.delete('/trip-recurrences/$id');
  }
}
