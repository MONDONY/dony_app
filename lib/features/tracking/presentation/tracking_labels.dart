import 'package:dony/l10n/l10n.dart';

/// Libellé traduit d'une étape de suivi.
///
/// `DEPART`/`TRANSIT`/`ARRIVEE` restent les valeurs de donnée (état local,
/// requêtes, comparaisons) — seul l'affichage passe par cette fonction.
/// Remplace les cinq tables `_etapeLabels`/`_eventTypes` locales des écrans
/// de lecture. Un code inconnu est rendu tel quel.
String trackingStepLabel(AppLocalizations l, String eventType) {
  return switch (eventType) {
    'DEPART' => l.trackingStepDeparture,
    'TRANSIT' => l.trackingStepTransit,
    'ARRIVEE' => l.trackingStepArrival,
    _ => eventType,
  };
}

/// Ancienneté d'une lecture hors-ligne, affichée dans la file d'attente
/// (`offline_scan_queue_screen.dart`, `offline_queue_bottom_sheet.dart`).
///
/// Les deux écrans avaient chacun leur propre copie de ce calcul, au
/// caractère près.
String scanRelativeTime(AppLocalizations l, Duration diff) {
  if (diff.inMinutes < 1) return l.scanAgoUnderMinute;
  if (diff.inMinutes < 60) return l.scanAgoMinutes(diff.inMinutes);
  return l.scanAgoHours(diff.inHours);
}
