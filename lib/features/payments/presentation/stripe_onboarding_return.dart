/// Écran qui a ouvert l'onboarding hébergé de Stripe Connect, pour y revenir.
///
/// Stripe renvoie vers le backend, qui redirige vers `yadony://stripe/onboarding/…`
/// sans savoir d'où l'utilisateur est parti. Deux écrans ouvrent ce lien :
/// `/connect/onboarding/intro` (devenir voyageur) et `/payments/onboarding`
/// (étape paiements de l'inscription, ou « Recevoir mes paiements »). Le retour
/// menait toujours au premier : venu de l'inscription, l'utilisateur perdait sa
/// jauge et atterrissait sur un écran sans rapport (feedback FLUTTER-3T).
///
/// Mémoire vive seulement : si le système tue l'app pendant le passage par le
/// navigateur, le retour retombe sur l'écran par défaut, comme avant.
class StripeOnboardingReturn {
  StripeOnboardingReturn._();

  static String? _origin;

  /// Retenu juste avant d'ouvrir le lien Stripe : la route complète, paramètres
  /// compris (l'entrée d'onboarding porte la jauge).
  static void remember(String location) => _origin = location;

  /// Route d'origine, consommée une seule fois : un second retour (lien Stripe
  /// rouvert depuis l'autre écran) ne doit pas ramener sur un écran périmé.
  static String? consume() {
    final origin = _origin;
    _origin = null;
    return origin;
  }
}
