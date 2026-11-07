import 'package:dony/app/open_deep_link.dart' show openLinkHosts;

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

/// Résout `yadony://annonce/{uuid}` et `https://yadony.com/annonce/{uuid}`, le
/// lien imprimé sur les affiches de trajet que le voyageur poste sur ses
/// propres canaux.
///
/// Renvoie la route applicative correspondante, ou `null` si l'URI n'a pas
/// exactement cette forme. La destination est le détail du trajet, qui gère
/// lui-même le cas d'un visiteur non propriétaire : une fois l'annonce chargée
/// et l'auth résolue, il bascule l'expéditeur venu de Facebook vers la vue
/// expéditeur du feed (sheet « Faire une demande »), seul le voyageur
/// propriétaire reste sur l'écran propriétaire.
String? resolveAnnouncementDeepLink(Uri uri) {
  final segments = _linkSegments(uri);
  if (segments == null) {
    return null;
  }
  if (segments.length != 1 || !_uuidPattern.hasMatch(segments.first)) {
    return null;
  }
  return '/announcements/${segments.first}/trip';
}

/// Segments qui suivent `annonce`, ou `null` si [uri] n'est pas un lien de ce genre.
///
/// Deux formes : `yadony://annonce/{uuid}` (bouton « Ouvrir dans l'app » de la
/// page publique) et `https://yadony.com/annonce/{uuid}`, le lien imprimé sur
/// l'affiche, ouvert directement par le système (lien universel iOS, App Link
/// Android). L'hôte web vient de [openLinkHosts], aligné sur
/// `public/.well-known/*` de yadony-web.
List<String>? _linkSegments(Uri uri) {
  if (uri.scheme == 'yadony' && uri.host == 'annonce') {
    return uri.pathSegments;
  }
  if (uri.scheme == 'https' &&
      openLinkHosts.contains(uri.host) &&
      uri.pathSegments.isNotEmpty &&
      uri.pathSegments.first == 'annonce') {
    return uri.pathSegments.sublist(1);
  }
  return null;
}
