import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';

class BusinessPrefsRemoteDatasource {
  final ApiClient _api;
  const BusinessPrefsRemoteDatasource(this._api);

  Future<UserBusinessPrefsDto> fetchPrefs() async {
    final resp = await _api.dio.get('/users/me/business-preferences');
    return UserBusinessPrefsDto.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> updatePrefs(UserBusinessPrefsDto dto) async {
    await _api.dio.put('/users/me/business-preferences', data: dto.toJson());
  }
}
