import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/auth/data/models/user_model.dart';

class TravelerUpgradeRepository {
  final ApiClient _apiClient;

  const TravelerUpgradeRepository(this._apiClient);

  Future<UserModel> activateTravelerRole() async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/users/me/roles/traveler/activate',
      );
      if (response.data == null) {
        throw const NetworkException('Réponse invalide du serveur');
      }
      return UserModel.fromJson(response.data!);
    } catch (e) {
      throw unwrapDioError(e);
    }
  }
}
