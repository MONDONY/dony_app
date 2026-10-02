import 'package:dony/features/activation/bloc/activation_cubit.dart';
import 'package:dony/features/auth/presentation/onboarding_step.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';

/// Query param de `/kyc/verify` portant l'écran où revenir une fois
/// l'identité vérifiée, hors onboarding.
///
/// Sans lui, un utilisateur arrêté par le contrôle d'identité au moment de
/// publier retombait sur l'accueil : l'intention était perdue, et PostHog
/// montrait que la moitié des comptes vérifiés ne publiaient jamais rien.
const String kycReturnParam = 'next';

/// Seuls écrans où revenir. `go` ne transporte pas d'`extra` : une route qui
/// en dépend (ex. `/bids/new`) planterait. Liste fermée aussi pour qu'un lien
/// forgé ne puisse pas rediriger ailleurs.
const Set<String> kycReturnRoutes = {
  '/trips/publish-intro',
  '/parcels/send-intro',
};

/// [raw] s'il fait partie de [kycReturnRoutes], `null` sinon.
String? kycReturnRouteOrNull(String? raw) =>
    raw != null && kycReturnRoutes.contains(raw) ? raw : null;

/// Emplacement de `/kyc/verify` avec ses deux marqueurs : parcours
/// d'onboarding et écran de retour.
String kycVerifyLocation({required bool fromOnboarding, String? returnTo}) {
  final params = <String, String>{
    if (fromOnboarding) onboardingEntryParam: onboardingEntryValue,
    kycReturnParam: ?kycReturnRouteOrNull(returnTo),
  };
  return Uri(
    path: '/kyc/verify',
    queryParameters: params.isEmpty ? null : params,
  ).toString();
}

/// Sortie de l'écran KYC (guidage après KYC). Inscription : `/first-steps`
/// quand l'onboarding se termine, sinon l'étape suivante. Hors inscription :
/// retour à l'action demandée, sinon premiers pas tant qu'aucune première
/// action n'est faite, sinon l'accueil.
String kycExitRoute({
  required String? onboardingDestination,
  required String? returnTo,
  required bool justVerified,
  required ActivationState activation,
}) {
  if (onboardingDestination != null) {
    return onboardingDestination == '/home'
        ? firstStepsRoute
        : onboardingDestination;
  }
  if (!justVerified) return '/home';
  if (returnTo != null) return returnTo;
  final notDone =
      activation is ActivationLoaded && !activation.status.firstActionDone;
  return notDone ? firstStepsRoute : '/home';
}
