import 'package:flutter/foundation.dart';

import 'package:dony/features/matching/data/models/search_params.dart';

/// Transporte des [SearchParams] entre écrans qui ne partagent pas de BLoC
/// (par ex. depuis le bouton "Envoyer un colis" de l'écran Envoyer vers
/// l'écran Accueil). L'écran consommateur écoute, applique les params, puis
/// appelle [consume] pour vider la valeur (one-shot).
class PendingSearchNotifier extends ChangeNotifier {
  SearchParams? _params;

  SearchParams? get params => _params;

  void setPending(SearchParams params) {
    _params = params;
    notifyListeners();
  }

  /// Lit les params en attente et les efface. Retourne null si aucun.
  SearchParams? consume() {
    final value = _params;
    _params = null;
    return value;
  }
}
