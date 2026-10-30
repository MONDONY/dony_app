import 'package:dony/features/activation/bloc/activation_cubit.dart';
import 'package:dony/features/auth/presentation/screens/first_steps_screen.dart';

/// Écran de vérification d'identité (statut, puis page du fournisseur).
const String kKycVerifyRoute = '/kyc/verify';

/// Query param de `/kyc/verify` portant l'écran où revenir une fois
/// l'identité vérifiée.
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

/// Emplacement de `/kyc/verify`, avec l'écran où revenir s'il est autorisé.
String kycVerifyLocation({String? returnTo}) {
  final next = kycReturnRouteOrNull(returnTo);
  return Uri(
    path: kKycVerifyRoute,
    queryParameters: next == null ? null : {kycReturnParam: next},
  ).toString();
}

/// Sortie de l'écran KYC (guidage après KYC) : une fois vérifié, retour à
/// l'action demandée, sinon premiers pas tant qu'aucune première action n'est
/// faite, sinon l'accueil. Pas encore vérifié : l'accueil.
String kycExitRoute({
  required String? returnTo,
  required bool justVerified,
  required ActivationState activation,
}) {
  if (!justVerified) return '/home';
  if (returnTo != null) return returnTo;
  final notDone =
      activation is ActivationLoaded && !activation.status.firstActionDone;
  return notDone ? firstStepsRoute : '/home';
}
