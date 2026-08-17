import 'package:dony/features/app_update/data/datasources/app_update_remote_config_datasource.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Verrou de version minimale : compare le `buildNumber` installé
/// (`package_info_plus`) au seuil publié via Remote Config
/// (`min_supported_build`).
///
/// Échoue toujours en mode ouvert : réseau indisponible, Remote Config
/// injoignable, ou `buildNumber` illisible laissent tous passer
/// l'utilisateur. Bloquer quelqu'un par erreur est pire que le laisser
/// passer un lancement de plus.
class AppUpdateService {
  AppUpdateService(
    this._configSource, {
    Future<PackageInfo> Function()? packageInfoLoader,
  }) : _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform;

  final AppUpdateConfigSource _configSource;
  final Future<PackageInfo> Function() _packageInfoLoader;
  PackageInfo? _packageInfo;

  /// Rafraîchit la valeur Remote Config en arrière-plan (appel réseau). À
  /// lancer en fire-and-forget depuis le bootstrap : une valeur plus
  /// récente ne sera prise en compte qu'au prochain lancement, pas pendant
  /// la session en cours (voir [isUpdateRequired]).
  Future<void> refresh() => _configSource.fetchAndActivate();

  /// `true` seulement si le `buildNumber` installé est strictement inférieur
  /// au seuil publié. Ne déclenche jamais de requête réseau : lit la
  /// dernière valeur Remote Config déjà connue.
  Future<bool> isUpdateRequired() async {
    try {
      final minBuild = _configSource.minSupportedBuild;
      if (minBuild <= 0) {
        return false;
      }
      final info = await _loadPackageInfo();
      final installedBuild = int.tryParse(info.buildNumber);
      if (installedBuild == null) {
        return false;
      }
      return installedBuild < minBuild;
    } catch (_) {
      return false;
    }
  }

  Future<PackageInfo> _loadPackageInfo() async {
    return _packageInfo ??= await _packageInfoLoader();
  }
}
