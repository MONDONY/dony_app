/// Destination de repli quand le paramètre `next` est absent ou suspect.
const String kNextRouteFallback = '/home';

/// Valide un paramètre `next` reçu dans une URL (lien profond compris) avant
/// d'y naviguer.
///
/// N'est accepté qu'un chemin interne : il commence par `/`, jamais par `//`
/// (URL relative au protocole, donc un autre hôte) ni par `/\` (certains
/// navigateurs la traitent comme `//`). Tout le reste (absent, vide, schéma,
/// hôte) retombe sur `/home`.
String sanitizeNextRoute(String? raw) {
  if (raw == null || raw.isEmpty) return kNextRouteFallback;
  if (!raw.startsWith('/')) return kNextRouteFallback;
  if (raw.startsWith('//') || raw.startsWith(r'/\')) {
    return kNextRouteFallback;
  }
  return raw;
}
