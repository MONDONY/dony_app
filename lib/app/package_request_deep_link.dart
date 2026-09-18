/// Motif d'identifiant accepté dans un lien profond paramétré : un UUID, rien
/// d'autre.
///
/// Une correspondance par simple préfixe suffirait à laisser passer
/// `yadony://demande/../admin`. Le segment est donc validé strictement, comme
/// l'exige la liste blanche exhaustive qui protège déjà les autres liens.
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Résout `yadony://demande/{uuid}`, le lien imprimé sur la page publique
/// d'une demande d'envoi que l'expéditeur partage sur ses propres canaux.
///
/// Renvoie la route applicative correspondante, ou `null` si l'URI n'a pas
/// exactement cette forme. La destination est le détail visiteur de la
/// demande, qui gère lui-même le cas d'un propriétaire venu cliquer son
/// propre lien : une fois la demande chargée et l'auth résolue, il bascule le
/// propriétaire authentifié vers son écran « Ma demande », seul un visiteur
/// reste sur la vue publique.
String? resolvePackageRequestDeepLink(Uri uri) {
  if (uri.scheme != 'yadony' || uri.host != 'demande') {
    return null;
  }
  final segments = uri.pathSegments;
  if (segments.length != 1 || !_uuidPattern.hasMatch(segments.first)) {
    return null;
  }
  return '/package-requests/${segments.first}/public';
}
