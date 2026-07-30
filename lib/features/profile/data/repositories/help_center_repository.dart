import 'dart:convert';

import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

final class HelpCenterRepository {
  HelpCenterRepository(
    this._source, {
    Future<String> Function()? fallbackJsonLoader,
    UrlLauncherPlatform? urlLauncher,
  }) : _fallbackJsonLoader = fallbackJsonLoader ?? _loadFallbackJson,
       _urlLauncher = urlLauncher ?? UrlLauncherPlatform.instance;

  static const _fallbackAssetPath =
      'assets/config/help_center_config.default.json';

  final HelpCenterConfigSource _source;
  final Future<String> Function() _fallbackJsonLoader;
  final UrlLauncherPlatform _urlLauncher;
  HelpCenterConfig _lastValid = HelpCenterConfig.empty;

  Future<HelpCenterConfig> load() async {
    HelpCenterConfig? activated;
    try {
      activated = _parse(_source.activatedJson);
    } catch (_) {
      // Une source défaillante ne doit pas empêcher l’utilisation du fallback.
    }
    if (activated != null) {
      return _remember(activated);
    }

    try {
      final fallback = _parse(await _fallbackJsonLoader());
      if (fallback != null) {
        return _remember(fallback);
      }
    } catch (_) {
      // Le fallback ne doit jamais empêcher l’ouverture du centre d’aide.
    }

    return _lastValid;
  }

  Future<HelpCenterConfig> refresh() async {
    try {
      final fetched = await _source.fetchAndActivate();
      final config = fetched == null ? null : _parse(fetched);
      if (config != null) {
        return _remember(config);
      }
    } catch (_) {
      // La dernière configuration valide reste utilisable hors ligne.
    }

    return _lastValid;
  }

  Future<bool> openExternal(Uri uri) async {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      return false;
    }

    try {
      return await _urlLauncher.launchUrl(
        uri.toString(),
        const LaunchOptions(mode: PreferredLaunchMode.externalApplication),
      );
    } catch (_) {
      return false;
    }
  }

  HelpCenterConfig _remember(HelpCenterConfig config) {
    _lastValid = config;
    return config;
  }

  HelpCenterConfig? _parse(String value) {
    if (value.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        return null;
      }
      return HelpCenterConfig.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  static Future<String> _loadFallbackJson() {
    return rootBundle.loadString(_fallbackAssetPath);
  }
}
