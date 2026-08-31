import 'package:flutter/foundation.dart';

/// L'offre PRO n'est pas encore ouverte commercialement : tant que le backend
/// ne confirme pas `pro_enabled=true` (réglage plateforme piloté depuis le
/// back-office), toute entrée PRO reste masquée. Repli sûr : masquer plutôt
/// que proposer une offre qui ne peut pas aboutir.
///
/// Quand l'offre est fermée, le serveur lève aussi les quotas des comptes
/// standard (annonces mensuelles, brouillons) : l'application n'a donc rien
/// à vendre, ni à promettre.
const bool kProEnabledDefault = false;

final ValueNotifier<bool> _proEnabledNotifier = ValueNotifier(
  kProEnabledDefault,
);

/// Écoute les changements du flag chargé depuis le backend
/// (`GET /config/pro-enabled`) ; `.value` donne l'état courant.
ValueListenable<bool> get proEnabledListenable => _proEnabledNotifier;

/// Met à jour le flag au démarrage avec la valeur backend
/// (`GET /config/pro-enabled`).
void setProEnabled(bool enabled) {
  _proEnabledNotifier.value = enabled;
}
