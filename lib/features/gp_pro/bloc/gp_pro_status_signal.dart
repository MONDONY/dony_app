import 'package:flutter/foundation.dart';

/// Signal « le statut GP Pro du voyageur a changé côté serveur » : une demande
/// est partie, a été annulée, ou le badge a été rendu.
///
/// Les lectures du statut ailleurs dans l'app (la ligne « GP Pro » du Profil,
/// qui vit dans un onglet gardé en mémoire) l'écoutent pour se relire, quel que
/// soit le chemin par lequel le voyageur a agi (écran GP Pro, feuille de statut,
/// écran de blocage, « Modifier le profil »). Un compteur plutôt qu'un booléen :
/// chaque changement réveille les écouteurs.
final ValueNotifier<int> gpProStatusChanged = ValueNotifier<int>(0);

/// À appeler après une action réussie qui change le statut GP Pro.
void notifyGpProStatusChanged() => gpProStatusChanged.value++;
