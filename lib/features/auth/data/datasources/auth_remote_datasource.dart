import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:intl/intl.dart';

class AuthRemoteDatasource {
  final ApiClient _apiClient;

  AuthRemoteDatasource(this._apiClient);

  Future<UserModel> register({required String phoneNumber}) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'phoneNumber': phoneNumber},
    );
    return UserModel.fromJson(response.data!);
  }

  /// Rattache au compte appelant les données posées pendant une session
  /// visiteur (favoris, alertes). Le jeton anonyme prouve la possession de la
  /// session invitée : il doit avoir été capturé AVANT la bascule
  /// d'authentification, seul instant où il est encore lisible. Réponse 204.
  Future<void> claimGuestData(String guestIdToken) async {
    await _apiClient.dio.post<void>(
      '/auth/guest/claim',
      data: {'guestIdToken': guestIdToken},
    );
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
    DateTime? birthDate,
    String? city,
    String? phoneNumber,
    String? bio,
    List<String>? languages,
    String? transportMode,
  }) async {
    final response = await _apiClient.dio.patch<Map<String, dynamic>>(
      '/auth/me',
      data: {
        'firstName': ?firstName,
        'lastName': ?lastName,
        if (birthDate != null)
          'birthDate': DateFormat('yyyy-MM-dd').format(birthDate),
        'city': ?city,
        'phoneNumber': ?phoneNumber,
        'bio': ?bio,
        'languages': ?languages,
        'transportMode': ?transportMode,
      },
    );
    return UserModel.fromJson(response.data!);
  }

  Future<UserModel> uploadAvatar(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'avatar.jpg'),
    });
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/me/avatar',
      data: form,
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

  /// Rattache une adresse au compte connecté. Adresse et code partent ensemble :
  /// le backend consomme l'OTP au moment d'écrire, donc la preuve de possession
  /// est intrinsèque. Renvoie le profil à jour.
  Future<UserModel> attachEmail({
    required String email,
    required String code,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/email-otp/attach',
      data: {'email': email, 'code': code},
    );
    return UserModel.fromJson(response.data!);
  }

  Future<UserModel> registerWithEmail({required String email}) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'email': email},
    );
    return UserModel.fromJson(response.data!);
  }

  Future<void> sendPhoneOtp(String phoneNumber) async {
    await _apiClient.dio.post<void>(
      '/auth/sms-otp/send',
      data: {'phoneNumber': phoneNumber},
    );
  }

  Future<String> verifyPhoneOtp(String phoneNumber, String code) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/sms-otp/verify',
      data: {'phoneNumber': phoneNumber, 'code': code},
    );
    return response.data!['customToken'] as String;
  }

  /// Rattache un numéro au compte connecté. Numéro et code partent ensemble :
  /// le backend consomme l'OTP au moment d'écrire, donc la preuve de possession
  /// est intrinsèque. Renvoie le profil à jour.
  Future<UserModel> attachPhone({
    required String phoneNumber,
    required String code,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/sms-otp/attach',
      data: {'phoneNumber': phoneNumber, 'code': code},
    );
    return UserModel.fromJson(response.data!);
  }
}
