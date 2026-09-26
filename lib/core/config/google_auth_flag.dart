import 'package:dony/core/config/environment.dart';
import 'package:flutter/foundation.dart';

/// Force l'environnement vu par [googleSignInAvailable] dans les tests : le
/// dart-define `ENVIRONMENT` est figé à la compilation.
@visibleForTesting
String? debugEnvironmentOverride;

/// Google Play re-signe les builds Android avec sa clé App Signing, dont le
/// client OAuth appartient au projet Firebase de production. Un build staging
/// distribué par le Play Store échoue donc sur Google (DEVELOPER_ERROR) ;
/// iOS n'est pas concerné, son client OAuth est identifié par le bundle ID.
bool isGoogleSignInAvailable({
  required String environment,
  required TargetPlatform platform,
  bool isWeb = kIsWeb,
}) {
  if (isWeb) return true;
  return !(environment == 'staging' && platform == TargetPlatform.android);
}

/// Disponibilité de la connexion Google pour ce build sur cet appareil.
bool get googleSignInAvailable => isGoogleSignInAvailable(
  environment: debugEnvironmentOverride ?? kEnvironment,
  platform: defaultTargetPlatform,
);
