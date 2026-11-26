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

/// Paramètre des écrans d'engagements : la publication a été arrêtée par la
/// vérification d'identité, la saisie gardée en brouillon local se rouvre
/// directement, sans la feuille des brouillons.
const String publishResumeParam = 'resume';
const String publishResumeKyc = 'kyc';

/// Retour au formulaire de trajet rempli, après la vérification.
const String kycResumeTripRoute =
    '/trips/publish-intro?$publishResumeParam=$publishResumeKyc';

/// Retour au formulaire de demande d'envoi rempli, après la vérification.
const String kycResumeParcelRoute =
    '/parcels/send-intro?$publishResumeParam=$publishResumeKyc';

/// Seuls écrans où revenir. `go` ne transporte pas d'`extra` : une route qui
/// en dépend (ex. `/bids/new`) planterait. Liste fermée aussi pour qu'un lien
/// forgé ne puisse pas rediriger ailleurs.
const Set<String> kycReturnRoutes = {
  '/trips/publish-intro',
  '/parcels/send-intro',
  kycResumeTripRoute,
  kycResumeParcelRoute,
};

/// Query param de `/kyc/verify` : la vérification a été ouverte par-dessus
/// un écran qui doit survivre (formulaire d'une demande sur un trajet, dont
/// la route dépend d'un `extra`). Les écrans KYC se referment alors par un
/// `pop`, au lieu du `go` qui viderait la pile : la page du fournisseur sur
/// `true` une fois le parcours terminé, l'écran de statut sur l'URL d'une
/// nouvelle tentative ou sans valeur. L'écran resté dessous enchaîne.
const String kycBackParam = 'back';

/// [queryParameters] demandent le retour par `pop` ([kycBackParam]).
bool kycBackRequested(Map<String, String> queryParameters) =>
    queryParameters[kycBackParam] == '1';

/// Le retour rouvre une saisie gardée en brouillon (vérification demandée au
/// clic sur « Publier »).
bool kycReturnKeepsDraft(String? returnTo) =>
    returnTo == kycResumeTripRoute || returnTo == kycResumeParcelRoute;

/// [raw] s'il fait partie de [kycReturnRoutes], `null` sinon.
String? kycReturnRouteOrNull(String? raw) =>
    raw != null && kycReturnRoutes.contains(raw) ? raw : null;

/// Emplacement de `/kyc/verify`, avec l'écran où revenir s'il est autorisé.
/// [back] : retour par `pop` à l'écran resté dessous ([kycBackParam]).
String kycVerifyLocation({String? returnTo, bool back = false}) {
  final next = kycReturnRouteOrNull(returnTo);
  final params = {kycReturnParam: ?next, if (back) kycBackParam: '1'};
  return Uri(
    path: kKycVerifyRoute,
    queryParameters: params.isEmpty ? null : params,
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
