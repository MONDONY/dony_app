import 'package:dony/core/config/transport_modes_flag.dart';

/// Étapes du formulaire « Publier un trajet ». L'étape Mode n'existe que
/// lorsque le voyageur a un vrai choix de mode ([showModeStepFor]).
enum TripFormStep {
  mode,
  trajet,
  capacite,
  prix,
  conditions;

  /// Valeur figée du brouillon local (clé `stepId`) : ne jamais la changer,
  /// un brouillon enregistré par une version de l'app doit rester lisible
  /// par la suivante.
  String get wire => name;

  /// Étape relue d'un brouillon ; une valeur absente ou inconnue vaut `null`.
  static TripFormStep? fromWire(String? wire) {
    for (final step in values) {
      if (step.wire == wire) return step;
    }
    return null;
  }
}

/// Étapes visibles, dans l'ordre : Mode en tête seulement si [showModeStep].
List<TripFormStep> tripFormSteps({required bool showModeStep}) => [
  if (showModeStep) TripFormStep.mode,
  TripFormStep.trajet,
  TripFormStep.capacite,
  TripFormStep.prix,
  TripFormStep.conditions,
];

/// Le formulaire ouvre-t-il l'étape Mode ?
///
/// - Modification : jamais, le mode d'un trajet publié ne change pas.
/// - Trajet dédié à une demande ([isLocked]) : seulement si la demande n'a
///   pas fixé de mode (« peu importe », [lockedModeKnown] faux) et que le
///   voyageur a un choix.
/// - Création : dès qu'il y a un choix de mode.
bool showModeStepFor({
  required bool isEdit,
  required bool isLocked,
  required bool lockedModeKnown,
  required TransportModesAvailability modes,
}) {
  if (isEdit) return false;
  if (isLocked) return !lockedModeKnown && modes.hasTripChoice;
  return modes.hasTripChoice;
}
