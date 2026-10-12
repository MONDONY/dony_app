import 'dart:async';

import 'package:flutter/foundation.dart';

/// Billets d'avion en affiliation : tant que le backend ne confirme pas
/// `flights_enabled=true` (réglage plateforme piloté depuis le back-office),
/// l'onglet Billets n'existe pas et la barre du bas reste celle d'avant
/// (cinq onglets avec libellés). Repli sûr : masquer plutôt que proposer une
/// fonction que le serveur refuserait (503 `flights-unavailable`).
const bool kFlightsEnabledDefault = false;

/// Attente maximale du flag par une route Billets ouverte au démarrage à
/// froid (deeplink, notification `FLIGHT_PRICE_ALERT`).
const Duration kFlightsFlagWait = Duration(seconds: 5);

final ValueNotifier<bool> _flightsEnabledNotifier = ValueNotifier(
  kFlightsEnabledDefault,
);

Completer<void> _flightsFlagLoaded = Completer<void>();

/// Écoute le flag chargé au démarrage (`GET /config/flights-enabled`) ;
/// `.value` donne l'état courant.
ValueListenable<bool> get flightsEnabledListenable => _flightsEnabledNotifier;

void setFlightsEnabled(bool enabled) {
  _flightsEnabledNotifier.value = enabled;
}

/// Signale la fin du chargement, réussi ou non.
void markFlightsFlagLoaded() {
  if (!_flightsFlagLoaded.isCompleted) _flightsFlagLoaded.complete();
}

/// État du flag une fois le chargement terminé (au plus [kFlightsFlagWait]) :
/// lu tout de suite, `.value` vaudrait encore le repli `false` et un lien
/// d'alerte ouvert au démarrage repartirait sur l'accueil.
Future<bool> flightsEnabledResolved() async {
  if (!_flightsFlagLoaded.isCompleted) {
    await _flightsFlagLoaded.future.timeout(kFlightsFlagWait, onTimeout: () {});
  }
  return _flightsEnabledNotifier.value;
}

@visibleForTesting
void resetFlightsFlagForTest() {
  _flightsEnabledNotifier.value = kFlightsEnabledDefault;
  _flightsFlagLoaded = Completer<void>();
}
