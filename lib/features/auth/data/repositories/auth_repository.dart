import 'package:dony/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:dony/features/auth/data/models/user_model.dart';

class AuthRepository {
  final AuthRemoteDatasource _datasource;

  AuthRepository(this._datasource);

  Future<UserModel> register({required String phoneNumber}) =>
      _datasource.register(phoneNumber: phoneNumber);

  Future<UserModel> getProfile() => _datasource.getProfile();

  Future<void> deleteAccount() => _datasource.deleteAccount();

  Future<UserModel> updateProfile({
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    String? city,
    String? phoneNumber,
    String? bio,
    List<String>? languages,
    String? transportMode,
  }) => _datasource.updateProfile(
    firstName: firstName,
    lastName: lastName,
    birthDate: birthDate,
    city: city,
    phoneNumber: phoneNumber,
    bio: bio,
    languages: languages,
    transportMode: transportMode,
  );

  Future<UserModel> uploadAvatar(String filePath) =>
      _datasource.uploadAvatar(filePath);

  Future<void> sendEmailOtp(String email) => _datasource.sendEmailOtp(email);

  Future<String> verifyEmailOtp(String email, String code) =>
      _datasource.verifyEmailOtp(email, code);

  Future<UserModel> attachEmail({
    required String email,
    required String code,
  }) => _datasource.attachEmail(email: email, code: code);

  Future<UserModel> registerWithEmail({required String email}) =>
      _datasource.registerWithEmail(email: email);

  Future<void> sendPhoneOtp(String phoneNumber) =>
      _datasource.sendPhoneOtp(phoneNumber);

  Future<String> verifyPhoneOtp(String phoneNumber, String code) =>
      _datasource.verifyPhoneOtp(phoneNumber, code);

  Future<UserModel> attachPhone({
    required String phoneNumber,
    required String code,
  }) => _datasource.attachPhone(phoneNumber: phoneNumber, code: code);
}
