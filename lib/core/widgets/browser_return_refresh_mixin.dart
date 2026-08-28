import 'package:flutter/widgets.dart';

/// Trio récurrent des écrans qui envoient l'utilisateur dans un navigateur
/// externe (portail de paiement PRO, onboarding Stripe Connect...) et
/// doivent rafraîchir leur état à son retour : observateur de cycle de vie
/// Flutter, drapeau retenant qu'un navigateur a été lancé, et
/// rafraîchissement déclenché seulement à la toute première reprise qui
/// suit ce lancement — jamais à une reprise « normale » (bascule d'app sans
/// navigateur ouvert), ce qui économiserait un appel réseau inutile à
/// chaque passage en arrière-plan.
///
/// Utilisation :
/// ```dart
/// class _FooState extends State<Foo>
///     with WidgetsBindingObserver, BrowserReturnRefreshMixin<Foo> {
///   void _openPortal() {
///     markBrowserLaunched();
///     // ouvrir le navigateur…
///   }
///
///   @override
///   void onResumedAfterBrowserLaunch() {
///     // rafraîchir l'état affiché.
///   }
/// }
/// ```
///
/// `with WidgetsBindingObserver` doit précéder ce mixin dans la clause
/// `with` : ce mixin s'appuie sur lui pour s'enregistrer/se désenregistrer
/// et override `didChangeAppLifecycleState`.
///
/// Vit dans `core/` parce que ce trio est écrit ailleurs dans l'app
/// (`ConnectOnboardingIntroScreen`) : ce mixin ne l'y remplace pas — cet
/// écran est hors du périmètre de la branche qui l'introduit — mais évite
/// qu'une troisième copie apparaisse pour les deux nouveaux hôtes du
/// bandeau/écran PRO.
mixin BrowserReturnRefreshMixin<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  bool _hasLaunchedBrowser = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// À appeler juste avant d'envoyer l'utilisateur dans le navigateur externe.
  void markBrowserLaunched() {
    _hasLaunchedBrowser = true;
  }

  /// À appeler quand l'ouverture du navigateur, annoncée par
  /// [markBrowserLaunched], échoue en réalité (URL invalide, aucun
  /// navigateur disponible…). Aucun navigateur n'a été ouvert : le drapeau
  /// de retour ne doit pas rester armé, sinon la prochaine reprise
  /// déclencherait un rafraîchissement sans raison.
  void clearBrowserLaunched() {
    _hasLaunchedBrowser = false;
  }

  /// Rafraîchissement à effectuer à la reprise qui suit un lancement de
  /// navigateur : quelque chose a pu changer hors de l'application.
  void onResumedAfterBrowserLaunch();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_hasLaunchedBrowser) {
      return;
    }
    _hasLaunchedBrowser = false;
    if (!mounted) return;
    onResumedAfterBrowserLaunch();
  }
}
