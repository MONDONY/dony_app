import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/auth/data/models/user_model.dart';

class AuthRemoteDatasource {
  final ApiClient _apiClient;

  AuthRemoteDatasource(this._apiClient);

  Future<UserModel> register({
    required String phoneNumber,
    required List<String> roles,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'phoneNumber': phoneNumber, 'roles': roles},
    );
    return UserModel.fromJson(response.data!);
  }

  Future<UserModel> getProfile() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>('/auth/me');
    return UserModel.fromJson(response.data!);
  }
}
