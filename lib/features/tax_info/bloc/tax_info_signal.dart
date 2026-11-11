import 'package:flutter/foundation.dart';

/// Signal « les informations fiscales du voyageur ont changé côté serveur » :
/// elles viennent d'être enregistrées depuis l'écran. La bannière du Profil
/// (onglet gardé en mémoire) l'écoute pour se relire. Un compteur plutôt qu'un
/// booléen : chaque changement réveille les écouteurs.
final ValueNotifier<int> taxInfoChanged = ValueNotifier<int>(0);

/// À appeler après un enregistrement réussi.
void notifyTaxInfoChanged() => taxInfoChanged.value++;
