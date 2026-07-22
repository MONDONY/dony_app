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
