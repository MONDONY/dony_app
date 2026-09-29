import 'package:dony/features/auth/presentation/onboarding_step.dart';

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
