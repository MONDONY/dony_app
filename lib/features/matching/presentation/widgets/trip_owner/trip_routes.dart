// Routes ouvertes depuis l'écran du trajet vu par son voyageur (grille
// d'actions, tuiles « À traiter », cartes directes du corps).

/// Activité › Demandes, onglet « À traiter », restreint au trajet [tripId]
/// (`/demandes?filter=aTraiter&announcement=<id>`).
String tripRequestsLocation(String tripId) => Uri(
  path: '/demandes',
  queryParameters: {'filter': 'aTraiter', 'announcement': tripId},
).toString();
