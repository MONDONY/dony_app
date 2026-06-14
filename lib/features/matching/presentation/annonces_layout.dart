/// Layout du tab Annonces — modèle additif Phase 1.
///
/// Logique pure (pas de dépendance Flutter) : détermine quelle vue doit être
/// montée dans le tab Annonces en fonction du profil de l'utilisateur.
enum AnnoncesLayout {
  /// Expéditeur pur — seule la vue « Envoyer » est visible.
  senderOnly,

  /// Voyageur occasionnel — vue « Envoyer » avec accès aux trajets via bouton.
  occasionalTraveler,

  /// Voyageur PRO — vue « Mes trajets » avec accès au formulaire d'envoi.
  proTraveler,
}

/// Retourne le layout Annonces approprié selon les capacités de l'utilisateur.
AnnoncesLayout annoncesLayoutFor({
  required bool isTraveler,
  required bool isPro,
}) {
  if (!isTraveler) {
    return AnnoncesLayout.senderOnly;
  }
  if (isPro) {
    return AnnoncesLayout.proTraveler;
  }
  return AnnoncesLayout.occasionalTraveler;
}
