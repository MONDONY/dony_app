import 'package:shared_preferences/shared_preferences.dart';

/// Mémoire locale du dernier « Plus tard » du modal de mise à jour.
///
/// Abstraction injectable : les tests la remplacent par une version en
/// mémoire.
abstract class AppUpdateSnoozeStore {
  /// Horodatage du dernier « Plus tard », ou `null` s'il n'y en a pas ou s'il
  /// est illisible.
  Future<DateTime?> lastSnoozedAt();

  /// Mémorise un « Plus tard » à [at]. Ne lève jamais : un échec d'écriture
  /// ne doit pas gêner l'utilisateur, le modal reviendra simplement.
  Future<void> snooze(DateTime at);
}

/// Version SharedPreferences : un horodatage en millisecondes epoch UTC.
class PrefsAppUpdateSnoozeStore implements AppUpdateSnoozeStore {
  PrefsAppUpdateSnoozeStore({Future<SharedPreferences> Function()? prefs})
    : _prefs = prefs ?? SharedPreferences.getInstance;

  static const key = 'app_update_snoozed_at_ms';

  final Future<SharedPreferences> Function() _prefs;

  @override
  Future<DateTime?> lastSnoozedAt() async {
    try {
      final prefs = await _prefs();
      final millis = prefs.getInt(key);
      if (millis == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> snooze(DateTime at) async {
    try {
      final prefs = await _prefs();
      await prefs.setInt(key, at.millisecondsSinceEpoch);
    } catch (_) {
      // Sans écriture, le modal reviendra au prochain lancement : acceptable.
    }
  }
}
