import 'package:flutter/foundation.dart';

/// Le SMS OTP est un canal secondaire encore en phase de test (essai Twilio,
/// pièce d'identité pas encore validée) — désactivé par défaut tant que le
/// backend ne confirme pas `app.sms.enabled=true`. Repli sûr : masquer plutôt
/// que proposer un bouton qui n'aboutit jamais.
const bool kSmsAuthEnabledDefault = false;

final ValueNotifier<bool> _smsAuthEnabledNotifier = ValueNotifier(
  kSmsAuthEnabledDefault,
);

/// Écoute les changements du flag chargé depuis le backend
/// (`GET /config/sms-enabled`) ; `.value` donne l'état courant.
ValueListenable<bool> get smsAuthEnabledListenable => _smsAuthEnabledNotifier;

/// Met à jour le flag au démarrage avec la valeur backend
/// (`GET /config/sms-enabled`).
void setSmsAuthEnabled(bool enabled) {
  _smsAuthEnabledNotifier.value = enabled;
}
