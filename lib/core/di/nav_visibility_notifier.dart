import 'package:flutter/foundation.dart';

/// Pilote l'affichage de la bottom nav flottante (île glass).
///
/// `value == true` → nav visible. Passée à `false` quand un sheet plein écran
/// (ex: la liste de l'accueil) la recouvre, pour qu'elle ne masque ni
/// n'intercepte le contenu ; ré-affichée quand le sheet revient en peek ou au
/// changement d'onglet.
class NavVisibilityNotifier extends ValueNotifier<bool> {
  NavVisibilityNotifier() : super(true);

  void show() => value = true;
  void hide() => value = false;
}
