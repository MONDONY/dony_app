import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';

class BusinessPrefsRemoteDatasource {
  final ApiClient _api;
  const BusinessPrefsRemoteDatasource(this._api);

  Future<UserBusinessPrefsDto> fetchPrefs() async {
    final resp = await _api.dio.get('/users/me/business-preferences');
    return UserBusinessPrefsDto.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Le `PUT` renvoie le DTO complet, devise recalculée par le serveur depuis
  /// le pays comprise : jeter cette réponse obligerait à relire les
  /// préférences juste après, ou pire à deviner la devise côté client.
  Future<UserBusinessPrefsDto> updatePrefs(UserBusinessPrefsDto dto) async {
    final resp = await _api.dio.put(
      '/users/me/business-preferences',
      data: dto.toJson(),
    );
    return UserBusinessPrefsDto.fromJson(resp.data as Map<String, dynamic>);
  }
}
