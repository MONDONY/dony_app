import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';

/// Écran ou feuille d'où l'accord IA est demandé, valeur analytics comprise.
enum AiConsentEntry {
  assistant('assistant'),
  formTrip('form_trip'),
  formPackageRequest('form_package_request');

  const AiConsentEntry(this.wire);

  final String wire;
}

/// Accord de l'utilisateur avant d'envoyer ses questions, ou le texte qu'il
/// dicte, à un fournisseur d'IA tiers (règle Apple 5.1.2(i)).
///
/// Un refus n'est pas mémorisé : la feuille revient à la prochaine ouverture,
/// l'accord ne se donne jamais par défaut.
class AiConsentService {
  AiConsentService(this._hive, this._analytics);

  final HiveService _hive;
  final AnalyticsService _analytics;

  bool get granted =>
      _hive.userPrefs.get(HiveService.kAiConsentGranted) == true;

  void markShown(AiConsentEntry entry) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.aiConsentShown,
        properties: {'entry': entry.wire},
      ),
    );
  }

  Future<void> answer({
    required bool granted,
    required AiConsentEntry entry,
  }) async {
    if (granted) {
      await _hive.userPrefs.put(HiveService.kAiConsentGranted, true);
    }
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.aiConsentAnswered,
        properties: {'granted': granted, 'entry': entry.wire},
      ),
    );
  }
}
