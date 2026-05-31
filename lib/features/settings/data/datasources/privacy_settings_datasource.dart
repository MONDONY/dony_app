import 'package:dony/core/network/api_client.dart';

class PrivacySettingsDatasource {
  final ApiClient _api;
  const PrivacySettingsDatasource(this._api);

  Future<bool> fetchContactKycOnly() async {
    final resp = await _api.dio.get('/auth/me/privacy-settings');
    return resp.data['contactKycOnly'] as bool;
  }

  Future<void> updateContactKycOnly(bool value) async {
    await _api.dio.put(
      '/auth/me/privacy-settings',
      data: {'contactKycOnly': value},
    );
  }
}
