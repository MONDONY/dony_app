import 'package:flutter/foundation.dart';

/// Signal « les informations fiscales du voyageur ont changé côté serveur » :
/// elles viennent d'être enregistrées depuis l'écran. La bannière du Profil
/// (onglet gardé en mémoire) l'écoute pour se relire. Un compteur plutôt qu'un
/// booléen : chaque changement réveille les écouteurs.
final ValueNotifier<int> taxInfoChanged = ValueNotifier<int>(0);

/// À appeler après un enregistrement réussi.
void notifyTaxInfoChanged() => taxInfoChanged.value++;

/// Demande de relecture du statut fiscal par l'entrée du Profil (onglet
/// Profil ouvert) : la bannière apparaît sans attendre la notification ni la
/// reprise de l'app. Hors de tout parcours d'acceptation ; un échec de lecture
/// est avalé par le cubit (jamais bloquant).
final ValueNotifier<int> taxInfoRefreshRequested = ValueNotifier<int>(0);

void requestTaxInfoRefresh() => taxInfoRefreshRequested.value++;
