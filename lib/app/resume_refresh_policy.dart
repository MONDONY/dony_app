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

/// Plancher entre deux relectures silencieuses du profil (reprise de l'app,
/// retour sur l'onglet Profil) : l'identité peut être validée hors de l'app
/// (admin, webhook) sans push reçu, mais l'API ne doit pas être sollicitée à
/// chaque retour au premier plan.
const Duration profileRefreshMinInterval = Duration(seconds: 30);

/// Retient l'instant de la dernière relecture du profil et dit si une nouvelle
/// est due. [shouldRefresh] consomme la fenêtre : un seul `true` par plancher.
class ProfileRefreshThrottle {
  ProfileRefreshThrottle({this.minInterval = profileRefreshMinInterval});

  final Duration minInterval;
  DateTime? _lastAt;

  bool shouldRefresh(DateTime now) {
    final last = _lastAt;
    if (last != null && now.difference(last) < minInterval) return false;
    _lastAt = now;
    return true;
  }
}
