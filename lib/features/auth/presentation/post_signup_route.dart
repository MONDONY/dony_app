import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
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

  // Cette garde ferme UN SEUL des trois points d'entrée du parcours : elle
  // empêche `resolvePostSignupRoute` lui-même de renvoyer indéfiniment vers
  // le pays un utilisateur qui l'a passé (`CountryOnboardingCubit.skip()`
  // laisse volontairement `country` à null). Deux autres chemins y entrent
  // sans jamais passer par ici ni par cette garde :
  // `AnalyticsConsentGate._onLogin` (`core/widgets/analytics_consent_gate.dart`)
  // renvoie vers `/auth/analytics-consent` à chaque login dont le
  // consentement analytics n'est pas répondu, quel que soit
  // `onboarding_seen_at` ; et le `redirect` de `router.dart` renvoie
  // `/trips/create` vers `/auth/country-selection` dès que
  // `kTravelerCountryUnsupported` est posé. Rouvrir ces deux chemins-là après
  // que l'utilisateur a atteint l'accueil est une décision produit qui
  // dépasse ce lot — signalé, pas corrigé ici (revue finale du lot 2,
  // correction 4).
  if (user?.onboardingSeenAt != null) return '/home';

  final step = nextStep(
    user: user,
    stripe: stripe,
    analyticsAnswered: !analytics.isConfigured || analytics.hasAnswered,
    countryFallback: countryFallback,
  );

  // Seul endroit qui connaît l'étape retenue : c'est ici, pas dans un widget,
  // qu'elle est tracée (sans PII, énumération fermée).
  final steps = onboardingSteps(stripe);
  if (step == null) {
    unawaited(
      analytics.logEvent(
        AnalyticsEvents.onboardingCompleted,
        properties: {'steps_total': steps.length},
      ),
    );
  } else {
    unawaited(
      analytics.logEvent(
        AnalyticsEvents.onboardingStepViewed,
        properties: {
          'step': step.wireName,
          'index': steps.indexOf(step) + 1,
          'total': steps.length,
        },
      ),
    );
  }

  // Rien à compléter : le parrainage clôt le parcours, et c'est lui qui pose
  // `onboarding_seen_at` (`referral_code_screen.dart:44`).
  return step?.route ?? '/auth/referral-code';
}
