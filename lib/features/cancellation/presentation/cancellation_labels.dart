import 'package:dony/l10n/l10n.dart';

/// Libellé affiché d'un motif d'annulation de trajet.
///
/// [reason] reste la valeur de donnée : envoyée au serveur
/// (`CancellationTripRequested.reason`) et comparée telle quelle
/// (`_selectedReason == 'Autre'`, `cancellation_bottom_sheet.dart`) — seul
/// l'affichage passe par cette fonction. Un motif inconnu (texte libre saisi
/// pour « Autre ») est rendu tel quel.
String cancellationReasonLabel(AppLocalizations l, String reason) {
  return switch (reason) {
    'Vol annulé' => l.cancellationReasonFlightCanceled,
    'Urgence personnelle' => l.cancellationReasonPersonalEmergency,
    'Problème de santé' => l.cancellationReasonHealthIssue,
    "Changement d'itinéraire" => l.cancellationReasonItineraryChange,
    'Autre' => l.cancellationReasonOther,
    _ => reason,
  };
}
