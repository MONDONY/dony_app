import 'package:dony/core/storage/hive_service.dart';
import 'package:hive/hive.dart';

/// Relance de la question de mesure d'usage, pour un compte qui n'a pas
/// répondu : 3 affichages de la feuille de l'accueil au plus, au moins 3 jours
/// entre deux. Le compte vit dans `user_prefs`.
///
/// Ne concerne que la feuille de l'accueil : l'écran « Une dernière chose »,
/// après le code de vérification, n'est pas compté.
class ConsentReminderPolicy {
  ConsentReminderPolicy(this._prefs);

  final Box<dynamic> _prefs;

  static const int maxReminders = 3;
  static const Duration gap = Duration(days: 3);

  /// Une relance est-elle due à [now] ? La première l'est tout de suite.
  bool shouldShow(DateTime now) {
    final count = (_prefs.get(HiveService.kConsentReminderCount) as int?) ?? 0;
    if (count == 0) return true;
    if (count >= maxReminders) return false;
    final last = DateTime.tryParse(
      _prefs.get(HiveService.kConsentReminderLastAt) as String? ?? '',
    );
    return last == null || !now.isBefore(last.add(gap));
  }

  /// À appeler quand la feuille s'ouvre vraiment.
  void markShown(DateTime now) {
    final count = (_prefs.get(HiveService.kConsentReminderCount) as int?) ?? 0;
    _prefs
      ..put(HiveService.kConsentReminderCount, count + 1)
      ..put(HiveService.kConsentReminderLastAt, now.toIso8601String());
  }
}
