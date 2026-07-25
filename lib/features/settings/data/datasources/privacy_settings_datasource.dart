import 'package:dony/core/network/api_client.dart';
import 'package:dony/features/settings/data/models/privacy_settings_model.dart';

class PrivacySettingsDatasource {
  final ApiClient _api;
  const PrivacySettingsDatasource(this._api);

  Future<PrivacySettingsModel> fetch() async {
    final resp = await _api.dio.get('/auth/me/privacy-settings');
    return PrivacySettingsModel.fromJson(resp.data as Map<String, dynamic>);
  }

  /// Le PUT porte toujours les deux préférences. Côté serveur un champ absent
  /// vaut « inchangé », donc n'envoyer que celle qui bouge fonctionnerait aussi ;
  /// pousser l'état complet évite une divergence si l'écran en gagne d'autres.
  Future<void> update(PrivacySettingsModel settings) async {
    await _api.dio.put(
      '/auth/me/privacy-settings',
      data: {
        'contactKycOnly': settings.contactKycOnly,
        'hidePhoneNumber': settings.hidePhoneNumber,
      },
    );
  }
}
