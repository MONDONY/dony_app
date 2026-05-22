import 'package:dony/features/settings/data/notification_prefs_datasource.dart';

class NotificationPrefsRepository {
  final NotificationPrefsDatasource _datasource;
  const NotificationPrefsRepository(this._datasource);

  Future<void> syncPrefs(Map<String, bool> prefs) async {
    try {
      await _datasource.syncPrefs(prefs);
    } catch (_) {
      // Échec silencieux — la valeur Hive locale est conservée
    }
  }
}
