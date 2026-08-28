import 'dart:convert';

import 'package:dony/core/services/external_url_launcher.dart';
import 'package:dony/features/profile/data/datasources/help_center_remote_config_datasource.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

enum HelpCenterRepositoryFailure { fetch, parse }

final class HelpCenterRepositoryResult {
  const HelpCenterRepositoryResult({required this.config, this.failure});

  final HelpCenterConfig config;
  final HelpCenterRepositoryFailure? failure;
}

final class HelpCenterRepository {
  HelpCenterRepository(
    this._source, {
    Future<String> Function()? fallbackJsonLoader,
    UrlLauncherPlatform? urlLauncher,
  }) : _fallbackJsonLoader = fallbackJsonLoader ?? _loadFallbackJson,
       _urlLauncher = ExternalUrlLauncher(launcher: urlLauncher);

  final HelpCenterConfigSource _source;
  final Future<String> Function() _fallbackJsonLoader;
  final ExternalUrlLauncher _urlLauncher;
  HelpCenterConfig _lastValid = HelpCenterConfig.empty;
  Future<void> _operationTail = Future.value();

  Future<HelpCenterRepositoryResult> load() => _serialize(_load);

  Future<HelpCenterRepositoryResult> _load() async {
    HelpCenterConfig? activated;
    try {
      activated = _parse(_source.activatedJson);
    } catch (_) {
      // Une source défaillante ne doit pas empêcher l’utilisation du fallback.
    }
    if (activated != null) {
      return _success(activated);
    }

    try {
      final fallback = _parse(await _fallbackJsonLoader());
      if (fallback != null) {
        return _success(fallback);
      }
    } catch (_) {
      // Le fallback ne doit jamais empêcher l’ouverture du centre d’aide.
    }

    return HelpCenterRepositoryResult(
      config: _lastValid,
      failure: HelpCenterRepositoryFailure.parse,
    );
  }

  Future<HelpCenterRepositoryResult> refresh() => _serialize(_refresh);

  Future<HelpCenterRepositoryResult> _refresh() async {
    try {
      final fetched = await _source.fetchAndActivate();
      if (fetched == null) {
        return HelpCenterRepositoryResult(
          config: _lastValid,
          failure: HelpCenterRepositoryFailure.fetch,
        );
      }
      final config = _parse(fetched);
      if (config != null) {
        return _success(config);
      }
      return HelpCenterRepositoryResult(
        config: _lastValid,
        failure: HelpCenterRepositoryFailure.parse,
      );
    } catch (_) {
      // La dernière configuration valide reste utilisable hors ligne.
      return HelpCenterRepositoryResult(
        config: _lastValid,
        failure: HelpCenterRepositoryFailure.fetch,
      );
    }
  }

  Future<bool> openExternal(Uri uri) => _urlLauncher.open(uri);

  HelpCenterRepositoryResult _success(HelpCenterConfig config) {
    _lastValid = config;
    return HelpCenterRepositoryResult(config: config);
  }

  Future<HelpCenterRepositoryResult> _serialize(
    Future<HelpCenterRepositoryResult> Function() operation,
  ) {
    final result = _operationTail.then((_) => operation());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
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
    return rootBundle.loadString(
      HelpCenterRemoteConfigDatasource.fallbackAssetPath,
    );
  }
}
