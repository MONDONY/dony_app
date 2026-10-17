import 'package:flutter/widgets.dart';

/// Garde le bas de la conversation collé au composeur quand la zone visible
/// change de hauteur : clavier qui s'ouvre ou se ferme (sur iOS sa hauteur
/// change à chaque image de l'animation), composeur qui gagne une ligne.
///
/// Sans elle, le `Scaffold` rétrécit le corps de la hauteur du clavier mais
/// l'offset de défilement ne bouge pas : les derniers messages passent sous le
/// composeur (Sentry FLUTTER-QT).
///
/// Le recalage se fait pendant le layout, dans l'image même où la hauteur
/// change ([ScrollPosition.correctForNewDimensions]) : pas d'image de retard,
/// pas d'animation à couper, rien à faire de plus quand les animations sont
/// réduites. Il ne s'applique que si la liste était au bas (à
/// [bottomTolerance] près) avant le changement et qu'aucun défilement n'est
/// en cours : un utilisateur qui a remonté pour lire, ou qui fait glisser la
/// liste, n'est pas ramené au bas. Un ajout de contenu à hauteur visible
/// constante n'est pas concerné : l'écran le fait défiler lui-même, en
/// animation.
class AssistantStickToBottomPhysics extends ScrollPhysics {
  const AssistantStickToBottomPhysics({super.parent});

  /// Distance au bas, en pixels logiques, en deçà de laquelle la liste est
  /// considérée au bas.
  static const double bottomTolerance = 24;

  @override
  AssistantStickToBottomPhysics applyTo(ScrollPhysics? ancestor) =>
      AssistantStickToBottomPhysics(parent: buildParent(ancestor));

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final viewportChanged =
        oldPosition.hasViewportDimension &&
        newPosition.hasViewportDimension &&
        oldPosition.viewportDimension != newPosition.viewportDimension;
    final wasAtBottom =
        oldPosition.hasContentDimensions &&
        oldPosition.hasPixels &&
        oldPosition.extentAfter <= bottomTolerance;
    if (viewportChanged &&
        wasAtBottom &&
        !isScrolling &&
        newPosition.hasContentDimensions) {
      return newPosition.maxScrollExtent;
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}
