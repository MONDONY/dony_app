import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:dony/l10n/l10n.dart';

/// Libellé affiché d'un motif d'annulation de trajet.
///
/// [reason] reste la valeur de donnée : envoyée au serveur
/// (`CancellationTripRequested.reason`) et comparée telle quelle
/// (`_selectedReason == 'Autre'`, `cancellation_bottom_sheet.dart`) — seul
/// l'affichage passe par cette fonction. Un motif inconnu (texte libre saisi
/// pour « Autre ») est rendu tel quel.
///
/// Le premier motif garde la valeur de donnée `'Vol annulé'` quel que soit le
/// mode du trajet ; son libellé suit [mode] : « Vol annulé » (avion, ou mode
/// absent), « Panne ou contretemps » (route, bus compris), « Transport
/// annulé » (bateau, train, autre).
String cancellationReasonLabel(
  AppLocalizations l,
  String reason, {
  TransportMode? mode,
}) {
  return switch (reason) {
    'Vol annulé' => _firstReasonLabel(l, mode), // i18n-ignore
    'Urgence personnelle' => // i18n-ignore
    l.cancellationReasonPersonalEmergency,
    'Problème de santé' => l.cancellationReasonHealthIssue, // i18n-ignore
    "Changement d'itinéraire" => // i18n-ignore
    l.cancellationReasonItineraryChange,
    'Autre' => l.cancellationReasonOther, // i18n-ignore
    _ => reason,
  };
}

String _firstReasonLabel(AppLocalizations l, TransportMode? mode) =>
    switch (transportModeOrPlane(mode)) {
      TransportMode.plane => l.cancellationReasonFlightCanceled,
      TransportMode.car || TransportMode.bus => l.cancellationReasonBreakdown,
      TransportMode.boat ||
      TransportMode.train ||
      TransportMode.other => l.cancellationReasonTransportCancelled,
    };
