/// « Tirer pour rafraîchir » de la liste plein écran de l'accueil.
///
/// La liste vit dans un `DraggableScrollableSheet` : tirée vers le bas depuis
/// son haut, c'est la feuille qui descend, la liste ne déborde jamais, et un
/// `RefreshIndicator` n'y verrait rien (recette du 14/11 : un trajet publié
/// entre-temps restait absent). La liste tirée puis relâchée avant la carte
/// revient sur la liste : ce va-et-vient vaut une demande de relance.
class HomeSheetPullRefresh {
  /// Taille en dessous de laquelle la feuille posée sur la liste a été tirée.
  static const double pulledBelow = 0.99;

  bool _pulled = false;

  /// À chaque changement de taille de la feuille. [settledOnList] : la
  /// dernière vue posée est la liste plein écran.
  void onSizeChanged(double size, {required bool settledOnList}) {
    if (settledOnList && size < pulledBelow) _pulled = true;
  }

  /// À la pose de la feuille, une fois le mouvement fini. Vrai quand la
  /// liste, déjà posée ([wasOnList]), a été tirée puis est revenue sur elle
  /// ([onList]) : relancer la recherche. Un passage par la carte, ou une
  /// ouverture de la liste depuis la carte, n'en est pas une.
  bool onSettled({required bool onList, required bool wasOnList}) {
    final pulled = _pulled;
    _pulled = false;
    return pulled && onList && wasOnList;
  }
}
