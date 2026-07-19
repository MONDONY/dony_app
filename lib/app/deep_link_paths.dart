/// Exhaustive allowlist — only these paths can be reached via `dony://` URIs.
/// Prevents crafted deep-links (e.g. `dony://admin/…`) from routing to
/// unintended screens.
///
/// Partagé entre deux points d'entrée :
/// - `app.dart` (`_DonyAppState._handleDeepLink`) — warm/hot start, via le
///   stream `app_links`.
/// - `router.dart` (redirect top-level de `GoRouter`) — cold start iOS : quand
///   l'app est lancée depuis zéro par un schéma custom, l'OS/Flutter transmet
///   l'URI brute (`dony://host/path`) directement au système de navigation de
///   GoRouter AVANT que `app_links.getInitialLink()` ne s'exécute côté Dart —
///   sans ce redirect, GoRouter tente de matcher l'URI complète comme un
///   chemin de route et lève `GoException: no routes for location: dony://…`.
const allowedDeepLinkPaths = {
  '/stripe/onboarding/complete',
  '/stripe/onboarding/refresh',
  '/payment/confirm',
  '/tracking/scan',
  '/wallet/topup-return/success',
  '/wallet/topup-return/error',
};
