import 'package:dio/dio.dart';
import 'package:dony/core/network/api_client.dart';

/// Écrit la langue du compte côté serveur (`PATCH /users/me/preferences`),
/// lue ensuite par tous les clients via `preferredLanguage` (`GET /auth/me`).
class UserLanguageRemoteDatasource {
  final ApiClient _api;

  const UserLanguageRemoteDatasource(this._api);

  /// `true` si le serveur a pris en compte le changement de langue.
  ///
  /// `false` (sans relancer) sur un backend qui ne connaît pas encore cette
  /// route (404) : l'app doit tolérer un backend plus ancien que ce contrat.
  Future<bool> update(String languageCode) async {
    try {
      await _api.dio.patch(
        '/users/me/preferences',
        data: {'language': languageCode},
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return false;
      rethrow;
    }
  }
}
