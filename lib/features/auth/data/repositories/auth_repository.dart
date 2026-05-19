import 'package:dony/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:dony/features/auth/data/models/user_model.dart';

class AuthRepository {
  final AuthRemoteDatasource _datasource;

  AuthRepository(this._datasource);

  Future<UserModel> register({
    required String phoneNumber,
    required List<String> roles,
  }) =>
      _datasource.register(phoneNumber: phoneNumber, roles: roles);

  Future<UserModel> getProfile() => _datasource.getProfile();

  Future<void> deleteAccount() => _datasource.deleteAccount();

  Future<UserModel> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    DateTime? birthDate,
    String? city,
  }) =>
      _datasource.updateProfile(
        firstName: firstName,
        lastName: lastName,
        email: email,
        birthDate: birthDate,
        city: city,
      );

  Future<void> sendEmailOtp(String email) =>
      _datasource.sendEmailOtp(email);

  Future<void> verifyEmailOtp(String email, String code) =>
      _datasource.verifyEmailOtp(email, code);

  Future<UserModel> registerWithEmail({
    required String email,
    required List<String> roles,
  }) =>
      _datasource.registerWithEmail(email: email, roles: roles);
}
