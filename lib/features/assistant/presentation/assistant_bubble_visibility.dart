import 'package:dony/app/deep_link_gate.dart';
import 'package:dony/features/auth/bloc/auth_state.dart';

/// Préfixes d'écrans où la bulle gênerait ou n'a pas de sens.
const _excludedPrefixes = <String>[
  // Mise à jour forcée (les `/auth/` et `/onboarding` sont des portes, voir
  // `isDeepLinkGateLocation`).
  '/force-update',
  // Vérification d'identité, onboarding Stripe, comptes bloqués.
  '/kyc/',
  '/connect/onboarding',
  '/stripe/onboarding',
  '/account/',
  // Caméra et scan QR plein écran.
  '/tracking/scan',
  '/tracking/validate',
  // Paiement.
  '/payments/',
  '/payment/',
  // Appel en cours, conversations (champ de saisie, pièces jointes), support.
  '/calls/',
  '/chat/',
  '/conversations/',
  '/support',
  // Lecteur vidéo des tutoriels.
  '/profile/help/tutorial/',
  // L'assistant lui-même.
  '/assistant',
];

/// Attente d'un paiement mobile money (offre ou négociation) : écran de
/// paiement, la bulle n'y a rien à faire.
const _excludedFragments = <String>[
  '/mobile-money/awaiting',
  // Création et changement du code PIN.
  '/change-pin',
  '/create-pin',
];

/// Écrans où la bulle gênerait : portes (onboarding, authentification, verrou
/// PIN, mise à jour forcée), KYC, scanner, paiement, conversations, support,
/// assistant et saisie du code PIN.
bool isAssistantBubbleExcludedLocation(String path) {
  if (isDeepLinkGateLocation(path)) return true;
  if (_isMoneyOverview(path)) return false;
  if (_excludedFragments.any(path.contains)) return true;
  return _excludedPrefixes.any(path.startsWith);
}

/// Portefeuille (solde, historique des remboursements) et « Mon argent » : des
/// écrans de consultation, pas de paiement. La recharge
/// (`/payments/wallet/topup/…`), le paiement et l'onboarding de versement
/// restent exclus.
bool _isMoneyOverview(String path) =>
    path == '/payments/wallet' ||
    path == '/payments/wallet/refunds' ||
    path == '/payments/money' ||
    path.startsWith('/payments/money/');

/// La bulle s'affiche pour un compte connecté qui ne l'a pas masquée, tant que
/// la sonde `/assistant/status` a répondu « disponible » ([available], faux par
/// défaut) et que l'assistant n'a pas répondu 404 ou 403 ([disabled]), hors clavier ouvert et hors écrans exclus.
bool shouldShowAssistantBubble({
  required String path,
  required bool signedIn,
  required bool enabled,
  required bool disabled,
  required bool available,
  required bool keyboardOpen,
}) =>
    path.isNotEmpty &&
    signedIn &&
    enabled &&
    available &&
    !disabled &&
    !keyboardOpen &&
    !isAssistantBubbleExcludedLocation(path);

/// Une session connectée (non invitée) est-elle ouverte après [state] ?
///
/// Seuls les états qui ferment la session masquent la bulle (initial, invité,
/// compte supprimé, verrou PIN). `AuthLoading` et `AuthError` ne disent rien
/// d'une session déjà ouverte (rafraîchissement du profil, échec d'une
/// requête) : on garde la réponse précédente, sinon la bulle clignoterait.
bool assistantSignedInAfter(AuthState state, {required bool previous}) {
  if (state.currentUser != null) return true;
  return switch (state) {
    AuthInitial() ||
    AuthGuestSessionReady() ||
    AuthAccountDeleted() ||
    AuthLocked() => false,
    _ => previous,
  };
}

/// [state] ferme-t-il la session du compte (déconnexion, compte supprimé,
/// session invitée) ? Un verrou PIN ([AuthLocked]) ne la ferme pas : c'est le
/// même compte, sa conversation lui reste.
bool assistantSessionClosedBy(AuthState state) => switch (state) {
  AuthInitial() || AuthGuestSessionReady() || AuthAccountDeleted() => true,
  _ => false,
};
