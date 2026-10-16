import 'package:go_router/go_router.dart';

/// Limites de cette vérification : elle ne regarde que le motif de chemin.
/// Les `redirect` du routeur ne sont pas suivis (une route redirigée reste
/// « existante », [assistantRouteNeedsGo] la traite à part) et un `extra`
/// obligatoire n'est pas vu. Ce qui borne les
/// routes que l'assistant peut proposer, c'est la liste blanche du back (les
/// routes des fiches), pas ce test : il écarte seulement une fiche périmée ou
/// une route inventée.
RouteMatchList? _match(GoRouter router, String path) {
  if (!path.startsWith('/') || path.startsWith('//')) return null;
  final uri = Uri.tryParse(path);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  try {
    final match = router.configuration.findMatch(uri);
    return match.isNotEmpty && !match.isError ? match : null;
  } catch (_) {
    return null;
  }
}

/// Vrai si [path] correspond à une route de l'app : une fiche périmée ou une
/// route inventée ne donne jamais un bouton mort. Accepte les segments
/// dynamiques (`/support/tickets/abc`) et ignore requête et fragment.
bool assistantRouteExists(GoRouter router, String path) =>
    _match(router, path) != null;

/// Vrai si [path] doit s'ouvrir par `go` plutôt que par `push` :
/// - il passe par un `StatefulShellRoute` ou un `ShellRoute` (barre
///   d'onglets) : un `push` depuis un écran hors shell, comme `/assistant`,
///   risque de dupliquer le shell ;
/// - une route du chemin (elle-même ou un parent) porte un `redirect` : la
///   destination réelle n'est connue qu'à la navigation, elle peut être un
///   onglet (`/flights/alerts` renvoie vers `/home` quand les billets sont
///   éteints). Dans le doute, `go`.
bool assistantRouteNeedsGo(GoRouter router, String path) {
  final match = _match(router, path);
  if (match == null) return false;
  return match.matches.any(
    (m) =>
        m.route is ShellRouteBase ||
        (m.route is GoRoute && (m.route as GoRoute).redirect != null),
  );
}
