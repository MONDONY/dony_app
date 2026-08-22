import 'package:dony/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:dony/features/auth/data/models/user_model.dart';

class AuthRepository {
  final AuthRemoteDatasource _datasource;

  AuthRepository(this._datasource);

  Future<UserModel> register({required String phoneNumber}) =>
      _datasource.register(phoneNumber: phoneNumber);

  /// Rattache les données du visiteur au compte appelant. À appeler APRÈS la
  /// création du compte serveur : sans la ligne de l'appelant, l'endpoint
  /// répond 404.
  Future<void> claimGuestData(String guestIdToken) =>
      _datasource.claimGuestData(guestIdToken);

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

  Future<void> updateResidenceAddress({
    required String street,
    String? line2,
    required String postalCode,
    required String city,
  }) => _datasource.updateResidenceAddress(
    street: street,
    line2: line2,
    postalCode: postalCode,
    city: city,
  );

  Future<void> markOnboardingSeen() => _datasource.markOnboardingSeen();
}
