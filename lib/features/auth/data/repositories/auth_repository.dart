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
    String? email,
    DateTime? birthDate,
    String? city,
    String? phoneNumber,
    String? bio,
    List<String>? languages,
    String? transportMode,
  }) => _datasource.updateProfile(
    firstName: firstName,
    lastName: lastName,
    email: email,
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

  Future<UserModel> registerWithEmail({required String email}) =>
      _datasource.registerWithEmail(email: email);
}
