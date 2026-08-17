import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Source de la clé Remote Config `min_supported_build` : le plus petit
/// `buildNumber` (`package_info_plus`) encore autorisé à faire tourner
/// l'application. Tant que rien n'est publié côté console, la clé n'existe
/// pas et le verrou reste inactif (voir [minSupportedBuild]).
abstract interface class AppUpdateConfigSource {
  /// Lecture instantanée de la dernière valeur activée (ou `0` si la clé
  /// n'a jamais été publiée) — jamais de réseau, jamais d'attente.
  int get minSupportedBuild;

  /// Récupère la dernière valeur publiée et l'active pour les lectures
  /// suivantes. Best-effort : toute erreur est avalée, [minSupportedBuild]
  /// retombe alors sur la dernière valeur connue.
  Future<void> fetchAndActivate();
}

abstract interface class AppUpdateRemoteConfigClient {
  int getInt(String key);

  Future<void> setConfigSettings(RemoteConfigSettings settings);

  Future<bool> fetchAndActivate();
}

final class FirebaseAppUpdateRemoteConfigClient
    implements AppUpdateRemoteConfigClient {
  FirebaseAppUpdateRemoteConfigClient(this._remoteConfig);

  final FirebaseRemoteConfig _remoteConfig;

  @override
  Future<bool> fetchAndActivate() => _remoteConfig.fetchAndActivate();

  @override
  int getInt(String key) => _remoteConfig.getInt(key);

  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) {
    return _remoteConfig.setConfigSettings(settings);
  }
}

/// Même motif que `HelpCenterRemoteConfigDatasource` (client abstrait +
/// implémentation Firebase, testable sans Firebase).
///
/// Différence volontaire : pas de `setDefaults`. Le SDK Firebase renvoie déjà
/// `0` pour une clé jamais publiée (voir doc `getInt`), et `setDefaults`
/// remplace *l'intégralité* de la table de defaults de l'instance partagée
/// `FirebaseRemoteConfig.instance` — un appel ici effacerait silencieusement
/// ceux déjà posés par `HelpCenterRemoteConfigDatasource` (et inversement).
final class AppUpdateRemoteConfigDatasource implements AppUpdateConfigSource {
  AppUpdateRemoteConfigDatasource({
    AppUpdateRemoteConfigClient? remoteConfig,
    bool? isDevelopment,
  }) : _remoteConfig =
           remoteConfig ??
           FirebaseAppUpdateRemoteConfigClient(FirebaseRemoteConfig.instance),
       _isDevelopment = isDevelopment ?? kDebugMode;

  /// Clé à créer dans la console Firebase Remote Config : entière, valeur
  /// par défaut 0.
  static const configKey = 'min_supported_build';

  final AppUpdateRemoteConfigClient _remoteConfig;
  final bool _isDevelopment;
  bool _isConfigured = false;

  @override
  int get minSupportedBuild {
    try {
      return _remoteConfig.getInt(configKey);
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> fetchAndActivate() async {
    try {
      await _configure();
      await _remoteConfig.fetchAndActivate();
    } catch (_) {
      // Best effort : la dernière valeur connue (ou 0) reste utilisable.
    }
  }

  Future<void> _configure() async {
    if (_isConfigured) {
      return;
    }
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: _isDevelopment
            ? const Duration(minutes: 5)
            : const Duration(hours: 12),
      ),
    );
    _isConfigured = true;
  }
}
