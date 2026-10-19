import 'package:go_router/go_router.dart';

/// Écrans-porte : tant que l'application s'y trouve, un lien profond ne doit
/// pas s'empiler par-dessus.
///
/// - `/auth/local` est le verrou PIN. Pousser la cible par-dessus le
///   contournait : le trajet, ses offres et la sheet s'affichaient sans code.
/// - Les autres `/auth/*` (méthode, OTP, infos perso, pays…) et `/onboarding`
///   sortent par un `go()` qui remplace toute la pile : un lien poussé avant
///   était perdu et la personne atterrissait sur l'accueil.
/// - `/force-update` ne laisse rien passer.
///
/// Le lien est retenu, puis rejoué dès que la route courante n'est plus une
/// porte (déverrouillage, connexion, session visiteur, fin d'onboarding).
bool isDeepLinkGateLocation(String location) =>
    location == '/onboarding' ||
    location == '/force-update' ||
    location.startsWith('/auth/');

/// Chemin de l'écran au sommet de la pile. `currentConfiguration.uri` reste
/// sur la route de base après un `push` (go_router 14) : l'écran poussé se
/// lit sur la dernière correspondance.
String topRouteLocation(GoRouter router) {
  final configuration = router.routerDelegate.currentConfiguration;
  if (configuration.isEmpty) return configuration.uri.path;
  return configuration.last.matchedLocation;
}

/// Vrai quand [route] vise l'écran d'attente mobile money déjà affiché
/// ([location]) : colis, fil de négociation ou supplément de prix. Le retour
/// Wave (ou la notification) arrive pendant que l'écran attend déjà : le
/// pousser une seconde fois empilait un second écran et un second bloc
/// (deux `payment_succeeded`, deux snackbars, deux `pop`). L'écran ouvert
/// sonde déjà et verra le paiement. Casse des UUID indifférente.
bool isAlreadyOnMobileMoneyAwaiting(String route, String location) {
  final path = Uri.parse(route).path.toLowerCase();
  return path.endsWith('/mobile-money/awaiting') &&
      path == location.toLowerCase();
}

/// Retient un lien profond arrivé sur un écran-porte et le rejoue une fois la
/// porte franchie. Un seul lien en attente : le dernier reçu gagne.
class DeepLinkGate {
  DeepLinkGate({
    required this.currentLocation,
    required this.navigate,
    String Function()? topLocation,
  }) : topLocation = topLocation ?? currentLocation;

  /// Chemin de la route courante du routeur (sans query).
  final String Function() currentLocation;

  /// Chemin de l'écran au sommet de la pile, écrans poussés compris
  /// ([topRouteLocation]) : sert à ne pas rouvrir l'écran d'attente mobile
  /// money déjà affiché.
  final String Function() topLocation;

  /// Navigation effective (cf. `_navigateToRoute` dans `app.dart`).
  final void Function(String route) navigate;

  String? _pending;

  /// Lien retenu, non encore rejoué (`null` sinon).
  String? get pendingRoute => _pending;

  /// Navigue tout de suite, ou retient [route] si l'app est sur une porte.
  void dispatch(String route) {
    final location = currentLocation();
    if (isDeepLinkGateLocation(location)) {
      _pending = route;
      return;
    }
    if (isAlreadyOnMobileMoneyAwaiting(route, topLocation())) return;
    navigate(route);
  }

  /// À appeler à chaque changement de route : rejoue le lien retenu dès que
  /// la porte est franchie. Le lien est consommé, il ne rejoue qu'une fois.
  void onLocationChanged() {
    final route = _pending;
    final location = currentLocation();
    if (route == null || isDeepLinkGateLocation(location)) {
      return;
    }
    _pending = null;
    if (isAlreadyOnMobileMoneyAwaiting(route, topLocation())) return;
    navigate(route);
  }
}
