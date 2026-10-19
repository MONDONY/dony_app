/// Motif d'identifiant accepté dans un lien profond paramétré : un UUID, rien
/// d'autre. Même motif que `announcement_deep_link.dart` (segment validé
/// strictement — une correspondance par simple préfixe laisserait passer un
/// chemin forgé).
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Résout `yadony://bids/{uuid}/mobile-money/awaiting`,
/// `yadony://negotiations/{uuid}/mobile-money/awaiting` et
/// `yadony://bids/{uuid}/supplements/{uuid}/mobile-money/awaiting` (retour
/// Wave ou notification) vers l'écran d'attente de la bonne portée.
///
/// Renvoie la route applicative correspondante, ou `null` si l'URI n'a pas
/// exactement l'une de ces formes.
String? resolveMobileMoneyAwaitingDeepLink(Uri uri) {
  if (uri.scheme != 'yadony') return null;
  if (uri.host != 'bids' && uri.host != 'negotiations') return null;
  final segments = uri.pathSegments;
  if (segments.isEmpty || !_uuidPattern.hasMatch(segments[0])) return null;
  final rest = segments.sublist(1);
  // Supplément de prix d'un colis : seulement sous `bids`.
  if (uri.host == 'bids' &&
      rest.length == 4 &&
      rest[0] == 'supplements' &&
      _uuidPattern.hasMatch(rest[1]) &&
      _isAwaitingTail(rest.sublist(2))) {
    return '/bids/${segments[0]}/supplements/${rest[1]}/mobile-money/awaiting';
  }
  if (!_isAwaitingTail(rest)) return null;
  return '/${uri.host}/${segments[0]}/mobile-money/awaiting';
}

bool _isAwaitingTail(List<String> tail) =>
    tail.length == 2 && tail[0] == 'mobile-money' && tail[1] == 'awaiting';
