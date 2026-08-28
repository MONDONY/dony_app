import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Ouverture d'URL externe, toujours en **navigateur externe**, jamais en
/// webview.
///
/// `HelpCenterRepository` et `BillingRepository` en délèguent chacun une
/// instance plutôt que de recopier la même garde et le même appel : avant ce
/// partage, les deux calquaient mot pour mot le même schéma (garde
/// scheme/host, mode d'ouverture, capture d'exception).
///
/// Le mode `externalApplication` n'est pas un détail : le mode par défaut du
/// paquet bascule une URL `https` en webview, et Stripe interdit ses
/// parcours de paiement dans une vue intégrée. `BillingRepository` en
/// dépend directement pour le portail PRO.
class ExternalUrlLauncher {
  ExternalUrlLauncher({UrlLauncherPlatform? launcher})
    : _launcher = launcher ?? UrlLauncherPlatform.instance;

  final UrlLauncherPlatform _launcher;

  /// Rend `false` sans tenter d'ouvrir quoi que ce soit pour un schéma non
  /// HTTPS ou un hôte vide, et `false` aussi si le lanceur échoue ou lève —
  /// jamais d'exception propagée à l'appelant.
  Future<bool> open(Uri uri) async {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      return false;
    }

    try {
      return await _launcher.launchUrl(
        uri.toString(),
        const LaunchOptions(mode: PreferredLaunchMode.externalApplication),
      );
    } catch (_) {
      return false;
    }
  }
}
