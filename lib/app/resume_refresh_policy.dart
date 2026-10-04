/// Absence minimale avant de relire, au retour au premier plan, ce qui ne
/// bouge pas en quelques secondes (support, compte Stripe).
const Duration resumeRefreshMinAbsence = Duration(seconds: 60);

/// Le retour au premier plan justifie-t-il de tout relire ?
///
/// [hiddenAt] est l'instant du dernier passage en arrière-plan
/// (`AppLifecycleState.hidden`), `null` si l'application n'a fait que perdre
/// le focus (Face ID, centre de notifications, fenêtre système) : ces faux
/// retours relançaient une salve de requêtes à chaque fois.
bool isResumeRefreshDue({required DateTime? hiddenAt, required DateTime now}) {
  if (hiddenAt == null) return false;
  return now.difference(hiddenAt) >= resumeRefreshMinAbsence;
}
