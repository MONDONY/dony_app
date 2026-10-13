/// Motif d'identifiant accepté : un UUID, rien d'autre (même garde que les
/// autres liens profonds paramétrés).
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Résout `yadony://flights/alerts/{uuid}/offers` (lien d'une notification
/// `FLIGHT_PRICE_ALERT`) vers l'écran « Vols trouvés » de l'alerte.
///
/// Renvoie la route applicative, ou `null` si l'URI n'a pas exactement cette
/// forme.
String? resolveFlightAlertOffersDeepLink(Uri uri) {
  if (uri.scheme != 'yadony' || uri.host != 'flights') return null;
  final segments = uri.pathSegments;
  if (segments.length != 3 ||
      segments[0] != 'alerts' ||
      !_uuidPattern.hasMatch(segments[1]) ||
      segments[2] != 'offers') {
    return null;
  }
  return '/flights/alerts/${segments[1]}/offers?source=notification';
}
