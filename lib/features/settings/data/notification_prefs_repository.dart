import 'package:dony/features/settings/data/notification_prefs_datasource.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

  /// Récupère les prefs depuis le backend et écrase Hive.
  /// Appelé au login pour réconcilier l'état par utilisateur.
  /// Silencieux en cas d'erreur réseau — Hive conserve ses valeurs.
  Future<void> fetchAndApplyPrefs(Box box) async {
    try {
      final prefs = await _datasource.fetchPrefs();
      for (final entry in prefs.entries) {
        await box.put('notif_${entry.key}', entry.value);
      }
    } catch (_) {
      // Pas de réseau ou backend indisponible — on garde les valeurs locales
    }
  }
}
