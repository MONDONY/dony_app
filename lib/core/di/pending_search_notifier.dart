import 'package:dony/features/matching/data/models/search_params.dart';
import 'package:flutter/foundation.dart';

/// Transporte des [SearchParams] entre écrans qui ne partagent pas de BLoC
/// (par ex. depuis le bouton "Publier un colis" de l'écran Envoyer vers
/// l'écran Accueil). L'écran consommateur écoute, applique les params, puis
/// appelle [consume] pour vider la valeur (one-shot).
///
/// Porte aussi une seconde intention, sans paramètre : ouvrir l'accueil sur
/// les colis compatibles avec les trajets du voyageur (écran de succès d'une
/// publication de trajet). Même cycle : on la pose, l'accueil la consomme.
class PendingSearchNotifier extends ChangeNotifier {
  SearchParams? _params;
  bool _parcelsForMyTrips = false;

  SearchParams? get params => _params;

  /// Vrai tant que l'accueil n'a pas consommé l'intention « colis pour mes
  /// trajets ».
  bool get hasParcelsForMyTrips => _parcelsForMyTrips;

  void setPending(SearchParams params) {
    _params = params;
    notifyListeners();
  }

  /// Demande à l'accueil de s'ouvrir en mode Colis, filtre « Pour mes trajets »
  /// actif.
  void setPendingParcelsForMyTrips() {
    _parcelsForMyTrips = true;
    notifyListeners();
  }

  /// Lit les params en attente et les efface. Retourne null si aucun.
  SearchParams? consume() {
    final value = _params;
    _params = null;
    return value;
  }

  /// Lit l'intention « colis pour mes trajets » et l'efface.
  bool consumeParcelsForMyTrips() {
    final value = _parcelsForMyTrips;
    _parcelsForMyTrips = false;
    return value;
  }
}
