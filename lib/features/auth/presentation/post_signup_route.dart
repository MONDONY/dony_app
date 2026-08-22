import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/auth/data/models/user_model.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/stripe_account/bloc/stripe_account_bloc.dart';

/// Route à suivre juste après la création du compte.
///
/// Fine enveloppe **asynchrone** autour de [nextStep] : la seule chose qu'elle
/// fait de plus est de réconcilier le consentement analytics avec le backend
/// avant de le lire. Sans ce sync, un utilisateur réinstallé (Hive vide, donc
/// `hasAnswered` faux à tort) qui a déjà consenti côté backend serait
/// redemandé — exactement la régression que la persistance backend élimine.
///
/// Toute la décision elle-même est dans la fonction pure, pour que la carte de
/// reprise (lot 4) ne puisse pas la contredire.
///
/// Anciennement `resolvePostPinSetupRoute`, puis une cascade de `if` pilotée
/// par le drapeau Hive `kCountryOnboardingSeen` : ce drapeau ne distinguait pas
/// l'étape pays de l'étape adresse et faisait sauter cette dernière.
Future<String> resolvePostSignupRoute({
  required AnalyticsService analytics,
  required UserModel? user,
  required StripeAccountState stripe,
  String? countryFallback,
}) async {
  if (analytics.isConfigured && !analytics.hasAnswered) {
    await analytics.syncFromBackend();
  }

  // Le parcours ne s'impose plus jamais une fois l'accueil atteint : on n'y
  // entre alors que par la carte de reprise. C'est aussi ce qui empêche de
  // renvoyer indéfiniment vers le pays un utilisateur qui l'a passé —
  // `CountryOnboardingCubit.skip()` laisse volontairement `country` à null.
  if (user?.onboardingSeenAt != null) return '/home';

  final step = nextStep(
    user: user,
    stripe: stripe,
    analyticsAnswered: !analytics.isConfigured || analytics.hasAnswered,
    countryFallback: countryFallback,
  );

  // Rien à compléter : le parrainage clôt le parcours, et c'est lui qui pose
  // `onboarding_seen_at` (`referral_code_screen.dart:44`).
  return step?.route ?? '/auth/referral-code';
}
