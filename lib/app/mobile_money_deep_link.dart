/// Motif d'identifiant accepté dans un lien profond paramétré : un UUID, rien
/// d'autre. Même motif que `announcement_deep_link.dart` (segment validé
/// strictement — une correspondance par simple préfixe laisserait passer un
/// chemin forgé).
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Résout `yadony://bids/{uuid}/mobile-money/awaiting` et
/// `yadony://negotiations/{uuid}/mobile-money/awaiting` (retour Wave ou
/// notification) vers l'écran d'attente de la bonne portée.
///
/// Renvoie la route applicative correspondante, ou `null` si l'URI n'a pas
/// exactement cette forme.
String? resolveMobileMoneyAwaitingDeepLink(Uri uri) {
  if (uri.scheme != 'yadony') return null;
  if (uri.host != 'bids' && uri.host != 'negotiations') return null;
  final segments = uri.pathSegments;
  if (segments.length != 3 ||
      !_uuidPattern.hasMatch(segments[0]) ||
      segments[1] != 'mobile-money' ||
      segments[2] != 'awaiting') {
    return null;
  }
  return '/${uri.host}/${segments[0]}/mobile-money/awaiting';
}
