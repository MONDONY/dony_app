import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/auth/data/models/user_model.dart';

/// En-tête du jeton de reconnexion renvoyé par `/auth/{email,sms}-otp/attach`.
const sessionTokenHeader = 'x-session-token';

/// Profil à jour après un rattachement d'email ou de numéro, plus le jeton
/// personnalisé qui rouvre la session Firebase.
///
/// Quand le backend écrit une coordonnée sur le compte Firebase, Firebase révoque
/// le jeton de rafraîchissement : la session tient jusqu'à l'expiration du jeton
/// d'identité, puis le premier rafraîchissement forcé (paiement, KYC, suivi)
/// déconnecte l'utilisateur (feedback FLUTTER-4C). `sessionToken` est `null`
/// avec un backend antérieur ou si Firebase n'a pas pu l'émettre.
typedef AttachResult = ({UserModel user, String? sessionToken});

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
    String? city,
    String? phoneNumber,
    String? bio,
    List<String>? languages,
  }) async {
    final response = await _apiClient.dio.patch<Map<String, dynamic>>(
      '/auth/me',
      data: {
        'firstName': ?firstName,
        'lastName': ?lastName,
        'city': ?city,
        'phoneNumber': ?phoneNumber,
        'bio': ?bio,
        'languages': ?languages,
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
  /// est intrinsèque. Renvoie le profil à jour et, si le backend en émet un,
  /// le jeton de reconnexion (voir [AttachResult]).
  Future<AttachResult> attachEmail({
    required String email,
    required String code,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/email-otp/attach',
      data: {'email': email, 'code': code},
    );
    return (
      user: UserModel.fromJson(response.data!),
      sessionToken: response.headers.value(sessionTokenHeader),
    );
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
  /// est intrinsèque. Renvoie le profil à jour et, si le backend en émet un,
  /// le jeton de reconnexion (voir [AttachResult]).
  Future<AttachResult> attachPhone({
    required String phoneNumber,
    required String code,
  }) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/auth/sms-otp/attach',
      data: {'phoneNumber': phoneNumber, 'code': code},
    );
    return (
      user: UserModel.fromJson(response.data!),
      sessionToken: response.headers.value(sessionTokenHeader),
    );
  }

  Future<void> markOnboardingSeen() async {
    await _apiClient.dio.put<void>('/auth/me/onboarding-seen');
  }
}
