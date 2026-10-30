import 'package:flutter/foundation.dart';

/// Demande de réponse au consentement de mesure d'usage.
///
/// [AnalyticsConsentGate] la lève à la connexion quand l'utilisateur doit
/// répondre ; le shell de l'accueil l'écoute et ouvre la feuille de
/// consentement. Elle reste levée tant qu'aucune réponse n'est enregistrée.
class ConsentPrompt {
  final ValueNotifier<bool> _wanted = ValueNotifier<bool>(false);

  /// `true` tant qu'une réponse est attendue.
  ValueListenable<bool> get wanted => _wanted;

  void request() => _wanted.value = true;

  void clear() => _wanted.value = false;
}
