import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/payments/cash/data/models/commission_method.dart';

class CommissionMethodRemoteDatasource {
  final ApiClient _client;

  CommissionMethodRemoteDatasource(this._client);

  Future<String> setup() async {
    final r = await _client.dio.post('/traveler/commission-method/setup');
    return r.data['clientSecret'] as String;
  }

  Future<CommissionMethod?> get() async {
    try {
      final r = await _client.dio.get('/traveler/commission-method');
      if (r.statusCode == 204 || r.data == null) {
        return null;
      }
      return CommissionMethod.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 204) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> delete() async {
    await _client.dio.delete('/traveler/commission-method');
  }
}
