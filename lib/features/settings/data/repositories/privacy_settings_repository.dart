import 'package:dony/features/settings/data/datasources/privacy_settings_datasource.dart';
import 'package:dony/features/settings/data/models/privacy_settings_model.dart';

class PrivacySettingsRepository {
  final PrivacySettingsDatasource _datasource;
  const PrivacySettingsRepository(this._datasource);

  Future<PrivacySettingsModel> fetch() => _datasource.fetch();

  Future<void> update(PrivacySettingsModel settings) =>
      _datasource.update(settings);
}
