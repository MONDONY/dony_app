import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/referral/data/pending_referral_code_store.dart';

/// Code parrain porté par `yadony://referral?code=ABCD1234` (bouton « Ouvrir
/// l'app » de la page `yadony.com/r/CODE`), ou `null` si l'URI n'a pas
/// exactement cette forme ou si le code n'est pas au format attendu.
String? resolveReferralCodeDeepLink(Uri uri) {
  if (uri.scheme != 'yadony' || uri.host != 'referral') return null;
  if (uri.pathSegments.any((segment) => segment.isNotEmpty)) return null;
  return PendingReferralCodeStore.normalize(uri.queryParameters['code']);
}

/// Traite un lien d'invitation : le code est gardé pour l'inscription, et un
/// compte connecté ouvre l'écran Parrainage, qui propose la saisie
/// pré-remplie s'il n'a pas encore de parrain. Pour une nouvelle inscription,
/// `PendingReferralRedeemer` applique le code gardé sans action de la
/// personne.
///
/// Rend `false` si [uri] n'est pas un lien d'invitation.
bool handleReferralDeepLink(
  Uri uri, {
  required PendingReferralCodeStore store,
  required AnalyticsService analytics,
  required bool signedIn,
  required void Function(String route) dispatch,
}) {
  final code = resolveReferralCodeDeepLink(uri);
  if (code == null) return false;
  unawaited(store.save(code));
  unawaited(
    analytics.logEvent(
      AnalyticsEvents.referralLinkOpened,
      properties: {'signed_in': signedIn},
    ),
  );
  // Sans compte, rien à ouvrir : l'inscription en cours (ou à venir)
  // retrouvera le code à la création du compte.
  if (signedIn) dispatch('/profile/referral?code=$code');
  return true;
}
