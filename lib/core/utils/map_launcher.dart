import 'dart:io' show Platform;

import 'package:dony/core/services/external_url_launcher.dart';

/// Construit l'URL d'ouverture d'un point (lat/lng) dans l'application de
/// cartographie native, en HTTPS uniquement — [ExternalUrlLauncher] rejette
/// tout schéma non `https`, et ces deux hôtes déclenchent quand même l'app
/// native installée (Plans / Google Maps) au lieu du navigateur.
///
/// [isApple] vrai → Apple Plans (iOS), faux → Google Maps (Android et autres).
/// Fonction pure pour rester testable sans dépendre de [Platform].
Uri buildMapUri({
  required double lat,
  required double lng,
  String? label,
  required bool isApple,
}) {
  final coords = '$lat,$lng';
  if (isApple) {
    // maps.apple.com : `ll` centre la carte, `q` pose l'épingle et son libellé.
    return Uri.https('maps.apple.com', '/', {
      'll': coords,
      if (label != null && label.isNotEmpty) 'q': label,
    });
  }
  // Google Maps Search API : ouvre l'app Google Maps sur le point.
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': coords,
  });
}

/// Ouvre [lat]/[lng] dans l'app de carte native de la plateforme (Plans sur
/// iOS, Google Maps sur Android), via [launcher]. Renvoie `false` sans lever si
/// l'ouverture échoue.
Future<bool> openInMaps(
  ExternalUrlLauncher launcher, {
  required double lat,
  required double lng,
  String? label,
}) {
  final uri = buildMapUri(
    lat: lat,
    lng: lng,
    label: label,
    isApple: Platform.isIOS || Platform.isMacOS,
  );
  return launcher.open(uri);
}
