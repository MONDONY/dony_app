import 'package:dony/core/design/accessibility_scope.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/auth/data/services/local_auth_service.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

/// Authentifie l'utilisateur avant un paiement, **si** il s'est donné un moyen
/// de le faire.
///
/// Commence par [confirmImportantAction] : si l'utilisateur a activé
/// « Confirmer les actions importantes » dans les réglages d'accessibilité, un
/// dialogue de confirmation explicite s'affiche avant toute vérification
/// biométrique ou PIN. Un refus à cette étape arrête la fonction immédiatement
/// (retourne `false`) sans qu'aucune authentification n'ait été tentée. Sans
/// l'option activée, cette étape est transparente et ne bloque jamais.
///
/// Les protections locales qui suivent sont facultatives : biométrie via
/// [kBiometricEnabled], code PIN selon qu'il en a créé un dans Réglages ›
/// Sécurité. N'ayant activé ni l'une ni l'autre, il n'y a rien à vérifier et le
/// paiement suit son cours — exiger un code inexistant rendrait tout paiement
/// impossible.
///
/// Si la biométrie est activée, elle passe d'abord, le PIN servant de repli.
/// Retourne `true` si le paiement peut continuer.
Future<bool> requirePaymentAuth(
  BuildContext context, {
  required LocalAuthService authService,
  required Box userPrefs,
}) async {
  final confirmed = await confirmImportantAction(
    context,
    title: 'Confirmer le paiement',
    message:
        'Le montant sera bloqué jusqu\'à la livraison, puis versé au voyageur.',
  );
  if (!confirmed) {
    return false;
  }

  final biometricPref =
      userPrefs.get(HiveService.kBiometricEnabled, defaultValue: false) as bool;

  bool authenticated = false;

  if (biometricPref) {
    final available = await authService.isBiometricAvailable();
    if (available) {
      authenticated = await authService.authenticateWithBiometric();
    }
  }

  // Repli PIN, uniquement s'il en existe un. Sans code configuré, ouvrir
  // l'écran de saisie mènerait à une impasse : rien à saisir, donc refus.
  if (!authenticated && !await authService.isPinSet()) {
    return true;
  }

  if (!authenticated && context.mounted) {
    final pinResult = await context.push<bool>('/auth/local?verify=true');
    authenticated = pinResult ?? false;
  }

  return authenticated;
}
