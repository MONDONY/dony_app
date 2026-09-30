import 'package:dony/app/deep_link_gate.dart';
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
  SystemBackDispatcher({required this.currentLocation, required this.navigate});

  /// Construit à partir du routeur de l'application.
  factory SystemBackDispatcher.forRouter(GoRouter router) =>
      SystemBackDispatcher(
        currentLocation: () =>
            router.routerDelegate.currentConfiguration.uri.path,
        navigate: router.go,
      );

  /// Chemin de la route courante (sans query).
  final String Function() currentLocation;

  /// Navigation de repli (remplace la pile).
  final void Function(String location) navigate;

  @override
  Future<bool> didPopRoute() async {
    if (await super.didPopRoute()) return true;
    final target = backFallbackFor(currentLocation());
    if (target == null) return false;
    navigate(target);
    return true;
  }
}
