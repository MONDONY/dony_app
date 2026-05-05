import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';

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
        data: {
          'companyName': companyName,
          'siret': siret,
        },
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }
}
