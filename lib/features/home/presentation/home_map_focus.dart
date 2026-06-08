/// Focus local de la carte Home pour les voyageurs.
/// Les purs expéditeurs (`isTraveler == false`) voient toujours les trajets
/// uniquement — le focus est ignoré pour eux.
enum HomeMapFocus { all, parcels, trips }

/// Résultat de visibilité de la carte : quels couches afficher.
class HomeMapVisibility {
  const HomeMapVisibility({
    required this.showTrips,
    required this.showParcels,
  });

  final bool showTrips;
  final bool showParcels;
}

/// Calcule les couches visibles selon la capacité de l'utilisateur et le focus
/// choisi. Logique pure, sans dépendance Flutter.
HomeMapVisibility homeMapVisibility({
  required bool isTraveler,
  required HomeMapFocus focus,
}) {
  if (!isTraveler) {
    // Expéditeur pur : toujours trajets, jamais colis.
    return const HomeMapVisibility(showTrips: true, showParcels: false);
  }
  switch (focus) {
    case HomeMapFocus.all:
      return const HomeMapVisibility(showTrips: true, showParcels: true);
    case HomeMapFocus.parcels:
      return const HomeMapVisibility(showTrips: false, showParcels: true);
    case HomeMapFocus.trips:
      return const HomeMapVisibility(showTrips: true, showParcels: false);
  }
}
