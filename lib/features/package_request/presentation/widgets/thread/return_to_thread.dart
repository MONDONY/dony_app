import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Quitte un écran de succès posé au-dessus d'un fil de négociation et
/// ramène l'utilisateur sur ce fil.
///
/// Les écrans de succès d'accord ou de paiement sont empilés au-dessus du fil
/// `/negotiations/:id` (la feuille d'action est ouverte depuis le fil). Un
/// simple `go('/negotiations/:id')` vise alors l'adresse déjà affichée :
/// go_router ne reconstruit rien et l'écran de succès, bloqué par son
/// `PopScope(canPop: false)`, reste à l'écran (Sentry FLUTTER-7J). On retire
/// donc d'abord l'écran de succès (`pop` ignore le `PopScope`), puis on ne
/// navigue que si le fil n'est pas l'adresse courante (écran ouvert par lien
/// direct, ou feuille lancée hors du fil).
void returnToNegotiationThread(BuildContext routeContext, String threadId) {
  final target = '/negotiations/$threadId';
  final router = GoRouter.of(routeContext);
  final navigator = Navigator.of(routeContext);
  if (navigator.canPop()) {
    navigator.pop();
  }
  if (router.state.uri.path != target) {
    router.go(target);
  }
}
