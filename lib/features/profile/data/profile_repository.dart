import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/profile/data/models/profile_public_model.dart';

class ProfileRepository {
  final ApiClient _client;

  ProfileRepository(this._client);

  Future<void> upgradeToPro({
    required String companyName,
    required String siret,
  }) async {
    try {
      await _client.dio.post(
        '/auth/me/upgrade-to-pro',
        data: {'companyName': companyName, 'siret': siret},
      );
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<void> downgradePro() async {
    try {
      await _client.dio.delete('/auth/me/upgrade-to-pro');
    } catch (e) {
      throw unwrapDioError(e);
    }
  }

  Future<ProfilePublicModel> getProfilePublic(String userId) async {
    try {
      final response = await _client.dio.get('/users/$userId/profile-public');
      return ProfilePublicModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
