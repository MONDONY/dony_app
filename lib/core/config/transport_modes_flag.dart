import 'package:dony/features/matching/data/models/transport_mode.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// L'écran de création de trajet gère le bateau depuis le lot 3 (choix C1,
/// C15) : proposé à la publication dès que l'interrupteur bateau du serveur
/// est allumé. Un voyageur non vérifié voit la carte grisée (étape Mode).
const bool kBoatTripCreationReady = true;

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

  /// Modes proposés aux modèles et aux trajets récurrents : jamais le bateau,
  /// que le back refuse (422 `boat-template-unsupported`, C16).
  List<TransportMode> get templateModes => [
    for (final mode in tripCreationModes)
      if (mode != TransportMode.boat) mode,
  ];

  bool get hasTripChoice => tripCreationModes.length > 1;

  bool get hasTemplateChoice => templateModes.length > 1;

  bool get hasRequestChoice => requestModes.length > 1;

  bool allowsForTrip(TransportMode mode) => tripCreationModes.contains(mode);

  /// Mêmes interrupteurs, bateau éteint : modes d'un trajet dédié à une
  /// demande, dont la version bateau (volume de la demande, fourchette
  /// d'arrivée) n'existe pas encore côté formulaire.
  TransportModesAvailability get withoutBoat =>
      TransportModesAvailability(road: road, boat: false);

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
