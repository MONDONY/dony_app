import 'package:dony/features/settings/data/datasources/privacy_settings_datasource.dart';

class PrivacySettingsRepository {
  final PrivacySettingsDatasource _datasource;
  const PrivacySettingsRepository(this._datasource);

  Future<bool> fetchContactKycOnly() => _datasource.fetchContactKycOnly();

  Future<void> updateContactKycOnly(bool value) =>
      _datasource.updateContactKycOnly(value);
}
