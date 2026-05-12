import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/recipients/data/models/recipient.dart';

class RecipientDatasource {
  final ApiClient _apiClient;

  RecipientDatasource(this._apiClient);

  Future<List<Recipient>> getAll() async {
    final response = await _apiClient.dio.get('/addressbook/recipients');
    return (response.data as List)
        .map((j) => Recipient.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Recipient> create(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post(
      '/addressbook/recipients',
      data: data,
    );
    return Recipient.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Recipient> update(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.dio.put(
      '/addressbook/recipients/$id',
      data: data,
    );
    return Recipient.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _apiClient.dio.delete('/addressbook/recipients/$id');
  }
}
