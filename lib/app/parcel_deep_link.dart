final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// `yadony://colis/{bidId}` : bouton « Ouvrir dans Yadony » de la page publique
/// du QR colis. Mène à l'écran de transition qui choisit la fiche selon le rôle
/// de l'utilisateur sur le colis.
String? resolveParcelDeepLink(Uri uri) {
  if (uri.scheme != 'yadony' || uri.host != 'colis') {
    return null;
  }
  final segments = uri.pathSegments;
  if (segments.length != 1 || !_uuidPattern.hasMatch(segments.first)) {
    return null;
  }
  return '/colis/${segments.first}';
}
