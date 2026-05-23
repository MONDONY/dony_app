import 'package:dony/features/settings/data/datasources/business_prefs_remote_datasource.dart';
import 'package:dony/features/settings/data/models/user_business_prefs_dto.dart';

class BusinessPrefsRepository {
  final BusinessPrefsRemoteDatasource _datasource;
  const BusinessPrefsRepository(this._datasource);

  Future<UserBusinessPrefsDto> fetchPrefs() => _datasource.fetchPrefs();

  Future<void> updatePrefs(UserBusinessPrefsDto dto) =>
      _datasource.updatePrefs(dto);
}
