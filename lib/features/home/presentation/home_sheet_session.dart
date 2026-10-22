import 'package:flutter/foundation.dart';

/// Mémoire, pour la durée du processus, de l'ouverture de la feuille de
/// résultats de l'onglet Rechercher.
///
/// La liste des annonces est ce que les testeurs viennent chercher : à la
/// première arrivée sur l'onglet depuis l'ouverture de l'app, la feuille se
/// pose donc à 100 %, au lieu de monter à mi-hauteur au-dessus de la carte. Les
/// retours suivants gardent la position où l'utilisateur a laissé l'onglet (le
/// `State` de l'écran survit au changement d'onglet) ; un nouvel écran créé
/// plus tard dans le même processus (reconnexion) reprend l'ouverture à
/// mi-hauteur, celle d'avant.
abstract final class HomeSheetSession {
  static bool _fullOpeningTaken = false;

  /// Éteint l'ouverture à 100 % : les tests de l'écran qui supposent la feuille
  /// repliée puis montée à mi-hauteur la coupent dans leur `setUp`.
  @visibleForTesting
  static bool fullOpeningEnabled = true;

  /// Vrai une seule fois par processus : l'écran qui l'obtient ouvre sa feuille
  /// à 100 %.
  static bool takeFullOpening() {
    if (!fullOpeningEnabled || _fullOpeningTaken) {
      return false;
    }
    _fullOpeningTaken = true;
    return true;
  }

  /// Remet la mémoire à zéro (tests).
  @visibleForTesting
  static void reset({bool enabled = true}) {
    _fullOpeningTaken = false;
    fullOpeningEnabled = enabled;
  }
}
