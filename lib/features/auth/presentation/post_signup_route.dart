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
/// Le parcours complet est en 4 étapes : `analytics_consent` →
/// `country_selection` → `residence_address` → `referral_code` → `/home`.
/// Ce résolveur ne renvoie jamais vers `/auth/residence-address` : le flag
/// `HiveService.kCountryOnboardingSeen` (posé par `CountryOnboardingCubit`,
/// que l'utilisateur ait choisi un pays ou non) ne distingue pas ces deux
/// étapes, et `/auth/referral-code` reste le fallback une fois l'onboarding
/// pays vu. En pratique ce résolveur ne rejoue quasiment jamais l'onboarding
/// : le compte se réinitialise à chaque inscription. Documentation seulement,
/// pas un comportement corrigé par le lot adresse de résidence.
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
  // Fallback terminal : ne renvoie jamais vers `/auth/residence-address`,
  // voir la doc de fonction ci-dessus.
  return '/auth/referral-code';
}
