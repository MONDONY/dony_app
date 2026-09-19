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

/// Retient un lien profond arrivé sur un écran-porte et le rejoue une fois la
/// porte franchie. Un seul lien en attente : le dernier reçu gagne.
class DeepLinkGate {
  DeepLinkGate({required this.currentLocation, required this.navigate});

  /// Chemin de la route courante du routeur (sans query).
  final String Function() currentLocation;

  /// Navigation effective (cf. `_navigateToRoute` dans `app.dart`).
  final void Function(String route) navigate;

  String? _pending;

  /// Lien retenu, non encore rejoué (`null` sinon).
  String? get pendingRoute => _pending;

  /// Navigue tout de suite, ou retient [route] si l'app est sur une porte.
  void dispatch(String route) {
    if (isDeepLinkGateLocation(currentLocation())) {
      _pending = route;
      return;
    }
    navigate(route);
  }

  /// À appeler à chaque changement de route : rejoue le lien retenu dès que
  /// la porte est franchie. Le lien est consommé, il ne rejoue qu'une fois.
  void onLocationChanged() {
    final route = _pending;
    if (route == null || isDeepLinkGateLocation(currentLocation())) {
      return;
    }
    _pending = null;
    navigate(route);
  }
}
