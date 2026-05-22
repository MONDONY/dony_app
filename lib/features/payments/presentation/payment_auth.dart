import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

/// Authentifie l'utilisateur avant un paiement.
///
/// Règle : auth TOUJOURS requise. Si [kBiometricEnabled] est activé, tente la
/// biométrie d'abord (fallback PIN). Sinon, PIN directement.
/// Retourne `true` si l'utilisateur est authentifié.
Future<bool> requirePaymentAuth(
  BuildContext context, {
  required LocalAuthService authService,
  required Box userPrefs,
}) async {
  final biometricPref =
      userPrefs.get(HiveService.kBiometricEnabled, defaultValue: false) as bool;

  bool authenticated = false;

  if (biometricPref) {
    final available = await authService.isBiometricAvailable();
    if (available) {
      authenticated = await authService.authenticateWithBiometric();
    }
  }

  // Fallback PIN si pas (encore) authentifié.
  if (!authenticated && context.mounted) {
    final pinResult = await context.push<bool>('/auth/local');
    authenticated = pinResult ?? false;
  }

  return authenticated;
}
