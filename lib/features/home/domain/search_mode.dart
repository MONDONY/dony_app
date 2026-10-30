import 'package:dony/features/activation/data/models/activation_status.dart';

/// Mode de recherche de l'écran Rechercher. Deux valeurs exclusives, une
/// toujours active : il n'existe pas de mode « les deux ». Les filtres, la
/// liste de résultats et les marqueurs de carte découlent de ce mode.
enum SearchMode {
  trips,
  parcels;

  bool get isTrips => this == SearchMode.trips;
  bool get isParcels => this == SearchMode.parcels;

  SearchMode get other => isTrips ? SearchMode.parcels : SearchMode.trips;
}

/// Mode d'ouverture de l'accueil selon l'intention déclarée : un voyageur
/// cherche des colis, tous les autres (expéditeur, les deux, inconnue) des
/// trajets.
SearchMode searchModeForIntent(UserIntent? intent) =>
    intent == UserIntent.traveler ? SearchMode.parcels : SearchMode.trips;
