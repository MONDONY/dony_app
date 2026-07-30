import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show rootBundle;

abstract interface class HelpCenterConfigSource {
  String get activatedJson;

  Future<String?> fetchAndActivate();
}

abstract interface class HelpCenterRemoteConfigClient {
  String getString(String key);

  Future<void> setConfigSettings(RemoteConfigSettings settings);

  Future<void> setDefaults(Map<String, dynamic> values);

  Future<bool> fetchAndActivate();
}

final class FirebaseHelpCenterRemoteConfigClient
    implements HelpCenterRemoteConfigClient {
  FirebaseHelpCenterRemoteConfigClient(this._remoteConfig);

  final FirebaseRemoteConfig _remoteConfig;

  @override
  Future<bool> fetchAndActivate() => _remoteConfig.fetchAndActivate();

  @override
  String getString(String key) => _remoteConfig.getString(key);

  @override
  Future<void> setConfigSettings(RemoteConfigSettings settings) {
    return _remoteConfig.setConfigSettings(settings);
  }

  @override
  Future<void> setDefaults(Map<String, dynamic> values) {
    return _remoteConfig.setDefaults(values);
  }
}

final class HelpCenterRemoteConfigDatasource implements HelpCenterConfigSource {
  HelpCenterRemoteConfigDatasource({
    HelpCenterRemoteConfigClient? remoteConfig,
    Future<String> Function()? fallbackJsonLoader,
    bool? isDevelopment,
  }) : _remoteConfig =
           remoteConfig ??
           FirebaseHelpCenterRemoteConfigClient(FirebaseRemoteConfig.instance),
       _fallbackJsonLoader = fallbackJsonLoader ?? _loadFallbackJson,
       _isDevelopment = isDevelopment ?? kDebugMode;

  static const configKey = 'help_center_config_v1';
  static const fallbackAssetPath =
      'assets/config/help_center_config.default.json';

  final HelpCenterRemoteConfigClient _remoteConfig;
  final Future<String> Function() _fallbackJsonLoader;
  final bool _isDevelopment;
  bool _isConfigured = false;

  @override
  String get activatedJson {
    try {
      return _remoteConfig.getString(configKey);
    } catch (_) {
      return '';
    }
  }

  @override
  Future<String?> fetchAndActivate() async {
    try {
      await _configure();
      await _remoteConfig.fetchAndActivate();
      return activatedJson;
    } catch (_) {
      return null;
    }
  }

  Future<void> _configure() async {
    if (_isConfigured) {
      return;
    }

    final fallbackJson = await _fallbackJsonLoader();
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: _isDevelopment
            ? const Duration(minutes: 5)
            : const Duration(hours: 12),
      ),
    );
    await _remoteConfig.setDefaults({configKey: fallbackJson});
    _isConfigured = true;
  }

  static Future<String> _loadFallbackJson() {
    return rootBundle.loadString(fallbackAssetPath);
  }
}
