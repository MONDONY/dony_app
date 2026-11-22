import 'package:flutter/foundation.dart';

/// Frais d'annulation de l'expéditeur allumés côté serveur
/// (`GET /config/cancellation-fee`, `active` vrai ET date d'effet posée).
///
/// Miroir de l'état de `CancellationFeeConfigCubit` (feature `cancellation`),
/// pour le code de `core/` qui ne voit pas les features : le catalogue des
/// erreurs choisit ici son texte. Repli sûr : éteint, les textes d'avant la
/// fonction, tant que la configuration n'est pas lue (back antérieur, hors
/// ligne, lecture ratée).
const bool _activeDefault = false;

final ValueNotifier<bool> _cancellationFeeActiveNotifier = ValueNotifier(
  _activeDefault,
);

/// Écoute le drapeau ; `.value` donne l'état courant.
ValueListenable<bool> get cancellationFeeActiveListenable =>
    _cancellationFeeActiveNotifier;

/// État courant du drapeau.
bool get cancellationFeeActive => _cancellationFeeActiveNotifier.value;

/// Mis à jour par `CancellationFeeConfigCubit` à chaque nouvel état.
void setCancellationFeeActive(bool active) {
  _cancellationFeeActiveNotifier.value = active;
}

@visibleForTesting
void resetCancellationFeeFlagForTest() {
  _cancellationFeeActiveNotifier.value = _activeDefault;
}
