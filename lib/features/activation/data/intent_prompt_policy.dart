import 'package:dony/core/storage/hive_service.dart';
import 'package:hive/hive.dart';

/// Question d'intention aux comptes existants : 2 affichages max, le second
/// au moins 7 jours après le premier. Le compte vit dans `user_prefs`.
class IntentPromptPolicy {
  IntentPromptPolicy(this._prefs);

  final Box<dynamic> _prefs;
  static const Duration _gap = Duration(days: 7);

  bool shouldShow(DateTime now) {
    final count = (_prefs.get(HiveService.kIntentPromptCount) as int?) ?? 0;
    if (count == 0) return true;
    if (count >= 2) return false;
    final last = DateTime.tryParse(
      _prefs.get(HiveService.kIntentPromptLastAt) as String? ?? '',
    );
    return last == null || !now.isBefore(last.add(_gap));
  }

  void markShown(DateTime now) {
    final count = (_prefs.get(HiveService.kIntentPromptCount) as int?) ?? 0;
    _prefs
      ..put(HiveService.kIntentPromptCount, count + 1)
      ..put(HiveService.kIntentPromptLastAt, now.toIso8601String());
  }
}
