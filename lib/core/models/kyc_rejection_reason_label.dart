/// Traduit le motif d'échec d'une vérification d'identité Stripe Identity
/// (`VerificationSession.last_error.code`, ex. `"document_expired"`) en message
/// compréhensible pour l'utilisateur.
///
/// Liste non exhaustive : les codes Stripe non couverts ci-dessous retombent
/// sur un message générique plutôt que d'afficher le code technique brut.
String kycRejectionReasonLabel(String? reason) {
  switch (reason) {
    case 'document_expired':
      return 'Le document fourni est expiré. Utilise une pièce d\'identité en cours de validité.';
    case 'document_type_not_supported':
      return 'Ce type de document n\'est pas accepté. Utilise une carte d\'identité, un passeport ou un permis de conduire.';
    case 'document_unverified_other':
      return 'Le document n\'a pas pu être vérifié. Prends une photo nette, sans reflet, avec les 4 coins visibles.';
    case 'selfie_document_mismatch':
      return 'Le selfie ne correspond pas à la photo du document. Réessaie dans un endroit bien éclairé.';
    case 'selfie_manipulated':
    case 'selfie_unverified_other':
      return 'Le selfie n\'a pas pu être vérifié. Réessaie en te filmant en direct, sans photo ni filtre.';
    case 'under_supported_age':
      return 'Yadony est réservé aux personnes majeures.';
    case 'consent_declined':
      return 'Le consentement à la vérification est requis pour continuer.';
    case 'device_not_supported':
      return 'Cet appareil ne permet pas de finaliser la vérification. Réessaie depuis un smartphone récent.';
    case 'country_not_supported':
      return 'Le pays de ce document n\'est pas pris en charge.';
    case 'abandoned':
      return 'La vérification a été interrompue avant la fin.';
    case 'session_canceled':
      return 'La vérification a été annulée.';
    default:
      return "Nous n'avons pas pu vérifier ton identité. Assure-toi que ton document est lisible et réessaie.";
  }
}
