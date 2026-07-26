import 'package:dony/features/settings/data/datasources/notification_prefs_remote_datasource.dart';
import 'package:dony/features/settings/data/models/notification_prefs_dto.dart';

class NotificationPrefsRepository {
  final NotificationPrefsRemoteDatasource _datasource;
  const NotificationPrefsRepository(this._datasource);

  Future<NotificationPrefsDto> fetchPrefs() => _datasource.fetchPrefs();

  Future<void> updatePrefs(NotificationPrefsDto dto) =>
      _datasource.updatePrefs(dto);
}
