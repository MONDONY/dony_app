import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:url_launcher/url_launcher.dart';

/// Ouvre la fiche de l'application sur le store de la plateforme. Partagé par
/// l'écran bloquant et le bandeau de mise à jour douce.
abstract final class AppStoreLauncher {
  static const androidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.yadony.yadony';

  /// Fiche App Store directe (identifiant Apple de l'app dans App Store
  /// Connect) : une recherche par nom pouvait proposer une autre app.
  static const iosStoreUrl = 'https://apps.apple.com/app/id6797821239';

  static Future<void> open() async {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final uri = Uri.parse(isIOS ? iosStoreUrl : androidStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
