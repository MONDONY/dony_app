import 'package:dony/features/tracking/data/models/scan_method.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/models/trip_scan_history_entry_model.dart';
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

/// Étape d'une ligne des derniers scans, suivie de sa provenance
/// (« Départ · QR », « Transit · numéro ») ; l'étape seule si elle est
/// inconnue.
String recentScanStepLabel(
  AppLocalizations l,
  TripScanHistoryEntryModel entry,
) {
  final step = trackingStepLabel(l, entry.eventType);
  return switch (entry.scanMethod) {
    ScanMethod.qr => l.suiviRecentScanStepByQr(step),
    ScanMethod.manual => l.suiviRecentScanStepByNumber(step),
    null => step,
  };
}

/// Ancienneté d'une lecture hors-ligne, affichée dans la file d'attente
/// (`offline_scan_queue_screen.dart`).
String scanRelativeTime(AppLocalizations l, Duration diff) {
  if (diff.inMinutes < 1) return l.scanAgoUnderMinute;
  if (diff.inMinutes < 60) return l.scanAgoMinutes(diff.inMinutes);
  return l.scanAgoHours(diff.inHours);
}

/// Libellés traduits d'un [TrackingEventModel] (frise de suivi,
/// `tracking_timeline_bottom_sheet.dart`).
///
/// Distinct de [trackingStepLabel] : ici le texte complet affiché à
/// l'expéditeur/destinataire (« Départ confirmé », etc.), pas le libellé
/// court des écrans de lecture (« Départ »). Remplace les getters
/// `stepLabel`/`displayLocationLabel` supprimés du modèle : `eventType`,
/// `gpsLabel`, `gpsLat`, `gpsLon` restent des valeurs de donnée, seul
/// l'affichage passe par cette extension.
extension TrackingEventL10n on TrackingEventModel {
  String stepLabel(AppLocalizations l) => switch (eventType) {
    'DEPART' => l.trackingEventDepartureConfirmed,
    'TRANSIT' => l.trackingEventInTransit,
    'ARRIVEE' => l.trackingEventArrivalConfirmed,
    _ => eventType,
  };

  String? locationLabel(AppLocalizations l) {
    final label = gpsLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    if (gpsLat != null && gpsLon != null) return l.trackingGpsRecorded;
    return null;
  }

  /// Comment l'étape a été validée, `null` si le back ne le sait pas.
  String? methodLabel(AppLocalizations l) => switch (scanMethod) {
    ScanMethod.qr => l.trackingValidatedByQr,
    ScanMethod.manual when photoUrl != null =>
      l.trackingValidatedByNumberWithPhoto,
    ScanMethod.manual => l.trackingValidatedByNumber,
    null => null,
  };
}
