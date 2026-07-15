import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/disputes/data/models/dispute_model.dart';

class DisputeRemoteDatasource {
  final ApiClient _apiClient;
  DisputeRemoteDatasource(this._apiClient);

  Future<List<DisputeModel>> getMyDisputes() async {
    final res = await _apiClient.dio.get<dynamic>('/disputes/me');
    return (res.data as List)
        .map((e) => DisputeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
