import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:stream_video_push_notification/stream_video_push_notification_platform_interface.dart';

/// Ce qui empêche un appel Yadony entrant de s'afficher sur l'écran
/// verrouillé (FLUTTER-92).
enum LockScreenCallBlocker {
  /// Rien de connu : l'appel s'affiche en plein écran.
  none,

  /// Android 14+ : l'autorisation « notifications plein écran » est refusée.
  /// Le Play Store ne l'accorde plus d'office qu'aux applis de téléphonie, et
  /// sans elle l'appel n'est qu'une notification, invisible écran verrouillé.
  fullScreenIntent,

  /// Xiaomi, Redmi, POCO (MIUI / HyperOS) : « Afficher sur l'écran de
  /// verrouillage » est désactivé par défaut et aucune API ne permet de le
  /// lire. On ne peut que guider vers la fiche de l'app.
  manufacturer,
}

/// Lit et ouvre les réglages système qui conditionnent l'affichage d'un appel
/// entrant sur l'écran verrouillé. Android uniquement : iOS passe par CallKit,
/// qui s'affiche toujours.
class CallLockScreenService {
  CallLockScreenService({
    bool Function()? isAndroid,
    Future<bool> Function()? canUseFullScreenIntent,
    Future<void> Function()? openFullScreenIntentSettings,
    Future<String> Function()? manufacturer,
    Future<void> Function()? openAppSettings,
  }) : _isAndroid =
           isAndroid ??
           (() => !kIsWeb && defaultTargetPlatform == TargetPlatform.android),
       _canUseFullScreenIntent =
           canUseFullScreenIntent ??
           StreamVideoPushNotificationPlatform.instance.canUseFullScreenIntent,
       _openFullScreenIntentSettings =
           openFullScreenIntentSettings ??
           StreamVideoPushNotificationPlatform
               .instance
               .ensureFullScreenIntentPermission,
       _manufacturer =
           manufacturer ??
           (() async => (await DeviceInfoPlugin().androidInfo).manufacturer),
       _openAppSettings = openAppSettings ?? AppSettings.openAppSettings;

  final bool Function() _isAndroid;
  final Future<bool> Function() _canUseFullScreenIntent;
  final Future<void> Function() _openFullScreenIntentSettings;
  final Future<String> Function() _manufacturer;
  final Future<void> Function() _openAppSettings;

  /// Faux sur iOS (CallKit s'affiche toujours) : rien à proposer.
  bool get isSupported => _isAndroid();

  static const _restrictiveManufacturers = {'xiaomi', 'redmi', 'poco'};

  /// Ne lève jamais : dans le doute, rien n'est signalé.
  Future<LockScreenCallBlocker> blocker() async {
    try {
      if (!_isAndroid()) return LockScreenCallBlocker.none;
      if (!await _canUseFullScreenIntent()) {
        return LockScreenCallBlocker.fullScreenIntent;
      }
      final brand = (await _manufacturer()).trim().toLowerCase();
      if (_restrictiveManufacturers.contains(brand)) {
        return LockScreenCallBlocker.manufacturer;
      }
    } catch (_) {
      // Plugin absent, canal natif indisponible : on ne bloque personne.
    }
    return LockScreenCallBlocker.none;
  }

  Future<void> openSettings(LockScreenCallBlocker blocker) async {
    switch (blocker) {
      case LockScreenCallBlocker.fullScreenIntent:
        await _openFullScreenIntentSettings();
      case LockScreenCallBlocker.manufacturer:
        await _openAppSettings();
      case LockScreenCallBlocker.none:
        return;
    }
  }
}
