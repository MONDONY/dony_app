import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/profile/data/models/profile_public_model.dart';

class ProfileRepository {
  final ApiClient _client;

  ProfileRepository(this._client);

  /// Retour en compte standard.
  ///
  /// Le pendant `POST /auth/me/upgrade-to-pro` n'existe plus côté client :
  /// il n'accorde plus le statut PRO côté serveur, la souscription se fait
  /// désormais sur le portail web Yadony PRO.
  ///
  /// Peut échouer en `409` RFC 7807 avec `code` = `active-stripe-subscription`
  /// (abonnement payant en cours) ou `not-pro-account`.
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
