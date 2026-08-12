import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/delivery_addresses/data/models/delivery_address.dart';

class DeliveryAddressDatasource {
  final ApiClient _apiClient;

  DeliveryAddressDatasource(this._apiClient);

  Future<List<DeliveryAddress>> getAll() async {
    final response = await _apiClient.dio.get('/addressbook/delivery-addresses');
    return (response.data as List)
        .map((j) => DeliveryAddress.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<DeliveryAddress> create(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post(
      '/addressbook/delivery-addresses',
      data: data,
    );
    return DeliveryAddress.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DeliveryAddress> update(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.dio.put(
      '/addressbook/delivery-addresses/$id',
      data: data,
    );
    return DeliveryAddress.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DeliveryAddress> setDefault(String id) async {
    final response = await _apiClient.dio.patch(
      '/addressbook/delivery-addresses/$id/set-default',
    );
    return DeliveryAddress.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _apiClient.dio.delete('/addressbook/delivery-addresses/$id');
  }
}
