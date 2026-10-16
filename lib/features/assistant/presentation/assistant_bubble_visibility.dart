import 'package:dony/app/deep_link_gate.dart';

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
  if (_excludedFragments.any(path.contains)) return true;
  return _excludedPrefixes.any(path.startsWith);
}

/// La bulle s'affiche pour un compte connecté qui ne l'a pas masquée, tant que
/// l'assistant est joignable, hors clavier ouvert et hors écrans exclus.
bool shouldShowAssistantBubble({
  required String path,
  required bool signedIn,
  required bool enabled,
  required bool disabled,
  required bool keyboardOpen,
}) =>
    signedIn &&
    enabled &&
    !disabled &&
    !keyboardOpen &&
    !isAssistantBubbleExcludedLocation(path);
