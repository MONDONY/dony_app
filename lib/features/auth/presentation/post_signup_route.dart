import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:hive/hive.dart';

/// Détermine la route à suivre juste après la création du compte, selon l'état
/// du consentement analytics.
///
/// Réconcilie d'abord avec le backend (source de vérité) si l'utilisateur n'a
/// pas de réponse locale : sans ce sync, un utilisateur réinstallé (Hive vide,
/// donc `hasAnswered` faux à tort) qui a déjà consenti côté backend serait
/// redemandé — exactement la régression que la persistance backend élimine.
///
/// - Consentement résolu + pays non vu → `/auth/country-selection`.
/// - Consentement résolu + pays vu → `/auth/referral-code`.
/// - Jamais répondu → `/auth/analytics-consent`, affiché à TOUT nouvel
///   utilisateur au 1er lancement, quel que soit le pays. Le choix reste
///   modifiable ensuite dans Réglages › Confidentialité.
///
/// [prefs] fournit le flag local de fin d'onboarding pays ; le pays n'est
/// plus discriminant depuis qu'on affiche l'écran de consentement partout.
///
/// Anciennement `resolvePostPinSetupRoute` : la création du code PIN ne fait
/// plus partie de l'inscription, elle est devenue un réglage facultatif.
Future<String> resolvePostSignupRoute(
  AnalyticsService analytics,
  Box<dynamic> prefs,
) async {
  if (analytics.isConfigured && !analytics.hasAnswered) {
    await analytics.syncFromBackend();
  }
  if (analytics.isConfigured && !analytics.hasAnswered) {
    return '/auth/analytics-consent';
  }
  if (prefs.get(HiveService.kCountryOnboardingSeen, defaultValue: false) !=
      true) {
    return '/auth/country-selection';
  }
  return '/auth/referral-code';
}
