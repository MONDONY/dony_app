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
}
