import 'package:flutter/foundation.dart';

/// Billets d'avion en affiliation : tant que le backend ne confirme pas
/// `flights_enabled=true` (réglage plateforme piloté depuis le back-office),
/// l'onglet Billets n'existe pas et la barre du bas reste celle d'avant
/// (cinq onglets avec libellés). Repli sûr : masquer plutôt que proposer une
/// fonction que le serveur refuserait (503 `flights-unavailable`).
const bool kFlightsEnabledDefault = false;

final ValueNotifier<bool> _flightsEnabledNotifier = ValueNotifier(
  kFlightsEnabledDefault,
);

/// Écoute le flag chargé au démarrage (`GET /config/flights-enabled`) ;
/// `.value` donne l'état courant.
ValueListenable<bool> get flightsEnabledListenable => _flightsEnabledNotifier;

void setFlightsEnabled(bool enabled) {
  _flightsEnabledNotifier.value = enabled;
}
