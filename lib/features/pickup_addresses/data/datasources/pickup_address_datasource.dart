import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/pickup_addresses/data/models/pickup_address.dart';

class PickupAddressDatasource {
  final ApiClient _apiClient;

  PickupAddressDatasource(this._apiClient);

  Future<List<PickupAddress>> getAll() async {
    final response = await _apiClient.dio.get('/addressbook/pickup-addresses');
    return (response.data as List)
        .map((j) => PickupAddress.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<PickupAddress> create(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post(
      '/addressbook/pickup-addresses',
      data: data,
    );
    return PickupAddress.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PickupAddress> update(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.dio.put(
      '/addressbook/pickup-addresses/$id',
      data: data,
    );
    return PickupAddress.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PickupAddress> setDefault(String id) async {
    final response = await _apiClient.dio.patch(
      '/addressbook/pickup-addresses/$id/set-default',
    );
    return PickupAddress.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _apiClient.dio.delete('/addressbook/pickup-addresses/$id');
  }
}
