import 'package:dony/app/deep_link_gate.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Destination du retour quand la pile n'a plus rien à dépiler, ou `null`
/// quand l'application doit se fermer.
///
/// Même repli pour le bouton retour des écrans (`DonyAppBarBackButton`,
/// `DonySliverAppBar`) et pour le retour système Android
/// ([SystemBackDispatcher]) : sans lui, un écran atteint par `go()` (détail
/// d'offre, négociation, portefeuille, onglets Activités/Suivi/Messages/Moi)
/// revenait à l'accueil par le bouton de l'écran, mais le retour du téléphone
/// fermait l'application.
///
/// L'accueil et les écrans-porte (connexion, onboarding, verrou PIN, mise à
/// jour forcée) ferment l'application : renvoyer vers l'accueil depuis le
/// verrou PIN le contournerait.
String? backFallbackFor(String location) {
  if (location == '/home' || isDeepLinkGateLocation(location)) return null;
  if (location.startsWith('/negotiations/')) return '/negotiations';
  if (location.startsWith('/settings/')) return '/settings';
  return '/home';
}

/// Retour système Android : d'abord le retour normal (feuille, dialogue,
/// page empilée, `PopScope`), puis le repli de [backFallbackFor] au lieu de
/// fermer l'application.
class SystemBackDispatcher extends RootBackButtonDispatcher {
  SystemBackDispatcher({
    required this.currentLocation,
    required this.navigate,
    this.isLocked,
  });

  /// Construit à partir du routeur de l'application.
  factory SystemBackDispatcher.forRouter(
    GoRouter router, {
    bool Function()? isLocked,
  }) => SystemBackDispatcher(
    currentLocation: () => router.routerDelegate.currentConfiguration.uri.path,
    navigate: router.go,
    isLocked: isLocked,
  );

  /// Chemin de la route courante (sans query).
  final String Function() currentLocation;

  /// Navigation de repli (remplace la pile).
  final void Function(String location) navigate;

  /// Vrai quand un écran recouvre toute l'application (mode maintenance) :
  /// le retour ne dépile rien sous lui et ferme l'application.
  final bool Function()? isLocked;

  @override
  Future<bool> didPopRoute() async {
    if (isLocked?.call() ?? false) {
      // Rendre `false` laisserait le framework dépiler sous l'écran : on
      // ferme l'application nous-mêmes et on consomme le retour.
      await SystemNavigator.pop();
      return true;
    }
    if (await super.didPopRoute()) return true;
    final target = backFallbackFor(currentLocation());
    if (target == null) return false;
    navigate(target);
    return true;
  }
}
