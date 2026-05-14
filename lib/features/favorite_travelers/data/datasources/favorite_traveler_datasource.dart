import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/favorite_travelers/data/models/favorite_traveler.dart';

class FavoriteTravelerDatasource {
  final ApiClient _apiClient;

  FavoriteTravelerDatasource(this._apiClient);

  Future<List<FavoriteTraveler>> getAll() async {
    final response =
        await _apiClient.dio.get('/addressbook/favorite-travelers');
    return (response.data as List)
        .map((j) => FavoriteTraveler.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> remove(String travelerId) async {
    await _apiClient.dio
        .delete('/addressbook/favorite-travelers/$travelerId');
  }
}
