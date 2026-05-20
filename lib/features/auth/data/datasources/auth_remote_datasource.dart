import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:intl/intl.dart';

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

  Future<void> deleteAccount() async {
    await _apiClient.dio.delete<void>('/auth/me');
  }

  Future<UserModel> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    DateTime? birthDate,
    String? city,
    String? phoneNumber,
  }) async {
    final response = await _apiClient.dio.patch<Map<String, dynamic>>(
      '/auth/me',
      data: {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (email != null) 'email': email,
        if (birthDate != null)
          'birthDate': DateFormat('yyyy-MM-dd').format(birthDate),
        if (city != null) 'city': city,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
      },
    );
    return UserModel.fromJson(response.data!);
  }

  Future<void> sendEmailOtp(String email) async {
    await _apiClient.dio.post<void>(
      '/auth/email-otp/send',
      data: {'email': email},
    );
  }

  Future<String> verifyEmailOtp(String email, String code) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/email-otp/verify',
      data: {'email': email, 'code': code},
    );
    return response.data!['customToken'] as String;
  }

  Future<UserModel> registerWithEmail({
    required String email,
    required List<String> roles,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'email': email, 'roles': roles},
    );
    return UserModel.fromJson(response.data!);
  }
}
