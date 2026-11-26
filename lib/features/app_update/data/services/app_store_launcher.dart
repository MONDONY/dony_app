import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lance la mise à jour de l'application sans faire quitter Yadony quand la
/// plateforme le permet. Partagé par l'écran bloquant et le modal de mise à
/// jour recommandée.
///
/// - **Android** : mise à jour Google Play dans l'app (Play Core,
///   `in_app_update`). Google affiche son écran de téléchargement puis
///   redémarre l'app à jour, sans passer par le Play Store.
/// - **iOS** : Apple n'offre aucune mise à jour depuis l'app. La fiche App Store
///   s'ouvre par-dessus Yadony (`SKStoreProductViewController`, canal natif
///   [iosChannel]) au lieu de basculer vers l'App Store.
///
/// Au moindre échec (app non installée depuis Google Play, Play Store absent,
/// canal natif indisponible), on retombe sur le lien du store, comme avant.
abstract final class AppStoreLauncher {
  static const androidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.yadony.yadony';

  /// Identifiant Apple de l'app dans App Store Connect.
  static const iosAppId = '6797821239';

  /// Fiche App Store directe : une recherche par nom pouvait proposer une
  /// autre app.
  static const iosStoreUrl = 'https://apps.apple.com/app/id$iosAppId';

  /// Canal natif iOS (`AppDelegate.swift`) qui présente la fiche App Store
  /// par-dessus l'app.
  static const iosChannel = MethodChannel('com.yadony.yadony/app_store');

  /// Remplaçable dans les tests : Play Core n'existe pas hors appareil.
  @visibleForTesting
  static PlayUpdateClient playClient = const InAppUpdatePlayClient();

  static Future<void> open() async {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final handled = isIOS
        ? await _showAppStoreOverlay()
        : await _startPlayUpdate();
    if (handled) return;
    await _openStoreUrl(isIOS ? iosStoreUrl : androidStoreUrl);
  }

  /// `true` si Google Play a pris la main (mise à jour lancée, ou refusée par
  /// l'utilisateur sur l'écran de Google). `false` quand aucune mise à jour
  /// Play n'est proposable : la fiche Play Store prend alors le relais.
  static Future<bool> _startPlayUpdate() async {
    try {
      final info = await playClient.checkForUpdate();
      final available =
          info.updateAvailability == UpdateAvailability.updateAvailable ||
          info.updateAvailability ==
              UpdateAvailability.developerTriggeredUpdateInProgress;
      if (!available || !info.immediateUpdateAllowed) return false;
      final result = await playClient.performImmediateUpdate();
      // Refus de l'utilisateur sur l'écran de Google : on n'insiste pas avec
      // le Play Store, le modal reviendra plus tard.
      return result != AppUpdateResult.inAppUpdateFailed;
    } catch (e) {
      debugPrint('[AppUpdate] Mise à jour Play impossible : $e');
      return false;
    }
  }

  static Future<bool> _showAppStoreOverlay() async {
    try {
      final shown = await iosChannel.invokeMethod<bool>('showProductPage', {
        'appId': iosAppId,
      });
      return shown ?? false;
    } catch (e) {
      debugPrint('[AppUpdate] Fiche App Store intégrée impossible : $e');
      return false;
    }
  }

  static Future<void> _openStoreUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Accès à Play Core, abstrait pour les tests.
abstract interface class PlayUpdateClient {
  Future<AppUpdateInfo> checkForUpdate();

  Future<AppUpdateResult> performImmediateUpdate();
}

final class InAppUpdatePlayClient implements PlayUpdateClient {
  const InAppUpdatePlayClient();

  @override
  Future<AppUpdateInfo> checkForUpdate() => InAppUpdate.checkForUpdate();

  @override
  Future<AppUpdateResult> performImmediateUpdate() =>
      InAppUpdate.performImmediateUpdate();
}
