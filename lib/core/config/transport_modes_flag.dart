import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Le bateau peut être demandé et recherché, mais pas encore proposé à la
/// publication d'un trajet : passe à `true` au lot 3 (choix C1), quand
/// l'écran de création de trajet gère le bateau.
const bool kBoatTripCreationReady = false;

/// Modes de transport ouverts par le serveur (`GET /config/transport-modes`,
/// réglages plateforme pilotés depuis le back-office). L'avion est toujours
/// proposé.
///
/// Repli sûr : avion seul. Un champ absent (serveur d'avant ces drapeaux), une
/// erreur réseau ou un flag pas encore chargé ne proposent jamais un mode que
/// le serveur refuserait (422 `transport-mode-disabled`).
@immutable
class TransportModesAvailability extends Equatable {
  final bool road;
  final bool boat;

  const TransportModesAvailability({required this.road, required this.boat});

  static const planeOnly = TransportModesAvailability(road: false, boat: false);

  /// Un champ absent ou non booléen vaut faux.
  factory TransportModesAvailability.fromJson(Map<String, dynamic> json) =>
      TransportModesAvailability(
        road: json['road'] == true,
        boat: json['boat'] == true,
      );

  /// Modes proposés à la publication d'un trajet.
  List<TransportMode> get tripCreationModes => [
    TransportMode.plane,
    if (road) TransportMode.car,
    if (boat && kBoatTripCreationReady) TransportMode.boat,
  ];

  /// Modes proposés à la demande d'envoi.
  List<TransportMode> get requestModes => [
    TransportMode.plane,
    if (boat) TransportMode.boat,
    if (road) TransportMode.car,
  ];

  /// Modes proposés dans les filtres de recherche.
  List<TransportMode> get searchModes => requestModes;

  bool get hasTripChoice => tripCreationModes.length > 1;

  bool get hasRequestChoice => requestModes.length > 1;

  bool allowsForTrip(TransportMode mode) => tripCreationModes.contains(mode);

  @override
  List<Object?> get props => [road, boat];
}

final ValueNotifier<TransportModesAvailability> _transportModesNotifier =
    ValueNotifier(TransportModesAvailability.planeOnly);

/// Dernière valeur connue : chargée au démarrage (`GET /config/transport-modes`).
ValueListenable<TransportModesAvailability> get transportModesListenable =>
    _transportModesNotifier;

TransportModesAvailability get transportModes => _transportModesNotifier.value;

void setTransportModes(TransportModesAvailability value) {
  _transportModesNotifier.value = value;
}

@visibleForTesting
void resetTransportModesForTest() {
  _transportModesNotifier.value = TransportModesAvailability.planeOnly;
}
