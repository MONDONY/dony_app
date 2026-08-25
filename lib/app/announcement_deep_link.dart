/// Motif d'identifiant accepté dans un lien profond paramétré : un UUID, rien
/// d'autre.
///
/// Une correspondance par simple préfixe suffirait à laisser passer
/// `yadony://annonce/../admin`. Le segment est donc validé strictement, comme
/// l'exige la liste blanche exhaustive qui protège déjà les autres liens.
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Résout `yadony://annonce/{uuid}`, le lien imprimé sur les affiches de trajet
/// que le voyageur poste sur ses propres canaux.
///
/// Renvoie la route applicative correspondante, ou `null` si l'URI n'a pas
/// exactement cette forme. La destination est le détail du trajet, qui gère
/// lui-même le cas d'un visiteur non propriétaire : un expéditeur venu de
/// Facebook y voit le trajet sans les actions réservées au voyageur.
String? resolveAnnouncementDeepLink(Uri uri) {
  if (uri.scheme != 'yadony' || uri.host != 'annonce') {
    return null;
  }
  final segments = uri.pathSegments;
  if (segments.length != 1 || !_uuidPattern.hasMatch(segments.first)) {
    return null;
  }
  return '/announcements/${segments.first}/trip';
}
