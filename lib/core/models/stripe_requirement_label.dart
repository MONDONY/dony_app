/// Traduit un champ Stripe encore manquant (`account.requirements.currently_due`,
/// ex. `"external_account"`) en message d'action compréhensible pour l'utilisateur.
///
/// Liste non exhaustive : les champs Stripe non couverts ci-dessous retombent
/// sur un message générique plutôt que d'afficher le code technique brut.
String stripeRequirementLabel(String requirement) {
  switch (requirement) {
    case 'external_account':
      return 'Ajoute ton IBAN';
    case 'individual.verification.document':
    case 'individual.verification.additional_document':
      return 'Envoie une pièce d\'identité';
    case 'individual.id_number':
      return 'Renseigne ton numéro de pièce d\'identité';
    case 'individual.dob.day':
    case 'individual.dob.month':
    case 'individual.dob.year':
      return 'Renseigne ta date de naissance';
    case 'individual.address.line1':
    case 'individual.address.city':
    case 'individual.address.postal_code':
    case 'individual.address.state':
      return 'Renseigne ton adresse';
    case 'individual.phone':
      return 'Renseigne ton numéro de téléphone';
    case 'individual.email':
      return 'Renseigne ton email';
    case 'tos_acceptance.date':
      return 'Accepte les conditions Stripe';
    default:
      return 'Complète les informations manquantes';
  }
}
