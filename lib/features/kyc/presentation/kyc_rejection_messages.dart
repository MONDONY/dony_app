/// Message FR affiché à l'utilisateur pour chaque code d'échec Stripe Identity
/// (`last_error.code` sur `identity.verification_session.requires_input`).
/// `null`/code inconnu → message générique en repli.
String kycRejectionMessage(String? rejectionCode) {
  switch (rejectionCode) {
    case 'document_expired':
      return 'Votre pièce d\'identité est expirée. Utilisez un document valide et réessayez.';
    case 'document_type_not_supported':
      return 'Ce type de document n\'est pas accepté. Utilisez une carte d\'identité, un passeport ou un permis de conduire.';
    case 'document_unverified_other':
      return 'Le document fourni n\'a pas pu être lu ou vérifié. Assurez-vous qu\'il est net, complet et bien éclairé, puis réessayez.';
    case 'country_not_supported':
      return 'Le pays de votre document n\'est pas pris en charge pour la vérification.';
    case 'id_number_insufficient_document_data':
    case 'id_number_mismatch':
    case 'id_number_unverified_other':
      return 'Les informations de votre document n\'ont pas pu être confirmées. Vérifiez qu\'elles sont bien lisibles et réessayez.';
    case 'selfie_document_missing_photo':
      return 'La photo sur votre document n\'a pas pu être comparée à votre selfie. Réessayez avec une pièce d\'identité comportant une photo nette.';
    case 'selfie_face_mismatch':
      return 'Votre selfie ne correspond pas à la photo du document. Reprenez la vérification dans de bonnes conditions de lumière.';
    case 'selfie_manipulated':
    case 'selfie_unverified_other':
      return 'Votre selfie n\'a pas pu être vérifié. Réessayez dans un endroit bien éclairé, sans lunettes ni couvre-chef.';
    case 'under_supported_age':
      return 'La vérification d\'identité est réservée aux personnes majeures.';
    case 'consent_declined':
      return 'Vous avez refusé de donner votre consentement, indispensable pour vérifier votre identité.';
    case 'session_canceled':
      return 'La vérification a été fermée avant d\'être terminée.';
    default:
      return 'Nous n\'avons pas pu vérifier votre identité. Assurez-vous que votre document est lisible et réessayez.';
  }
}
