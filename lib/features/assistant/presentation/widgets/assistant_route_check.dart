import 'package:go_router/go_router.dart';

/// Vrai si [path] correspond à une route de l'app : une fiche périmée ou une
/// route inventée ne donne jamais un bouton mort. Accepte les segments
/// dynamiques (`/support/tickets/abc`) et ignore requête et fragment.
bool assistantRouteExists(GoRouter router, String path) {
  if (!path.startsWith('/') || path.startsWith('//')) return false;
  final uri = Uri.tryParse(path);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return false;
  try {
    final match = router.configuration.findMatch(uri);
    return match.isNotEmpty && !match.isError;
  } catch (_) {
    return false;
  }
}
