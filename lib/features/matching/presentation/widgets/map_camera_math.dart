import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Distance grand-cercle (Haversine) entre deux points, en kilomètres.
double distanceKm(LatLng a, LatLng b) {
  const earthR = 6371.0;
  double rad(double d) => d * math.pi / 180.0;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final lat1 = rad(a.latitude);
  final lat2 = rad(b.latitude);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earthR * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Cadre « hybride » : englobe la position [user] + les annonces proches.
///
/// - Aucune annonce → `null` (l'appelant centre sur l'utilisateur au zoom ville).
/// - Annonces ≤ [nearbyRadiusKm] → cadre = user + ces annonces.
/// - Aucune dans le rayon → cadre = user + les [maxNearest] plus proches.
/// - Cadre dégénéré (un seul point ≈ user) → `null`.
LatLngBounds? computeHybridBounds(
  LatLng user,
  List<LatLng> points, {
  double nearbyRadiusKm = 150,
  int maxNearest = 10,
}) {
  if (points.isEmpty) {
    return null;
  }

  final within = points
      .where((p) => distanceKm(user, p) <= nearbyRadiusKm)
      .toList();

  final List<LatLng> selected;
  if (within.isNotEmpty) {
    selected = within;
  } else {
    final sorted = [...points]
      ..sort((a, b) => distanceKm(user, a).compareTo(distanceKm(user, b)));
    selected = sorted.take(maxNearest).toList();
  }

  final all = <LatLng>[user, ...selected];
  double minLat = all.first.latitude, maxLat = all.first.latitude;
  double minLng = all.first.longitude, maxLng = all.first.longitude;
  for (final p in all) {
    minLat = math.min(minLat, p.latitude);
    maxLat = math.max(maxLat, p.latitude);
    minLng = math.min(minLng, p.longitude);
    maxLng = math.max(maxLng, p.longitude);
  }

  // Garde anti-crash : `newLatLngBounds` plante si SW == NE.
  if ((maxLat - minLat).abs() < 1e-6 && (maxLng - minLng).abs() < 1e-6) {
    return null;
  }

  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

/// Cadre carré d'environ [radiusKm] de rayon autour de [center].
///
/// Sert au cadrage initial de la carte : centrer sur l'utilisateur tout en
/// montrant une large zone (≈ région / pays) au lieu d'un zoom serré.
LatLngBounds boundsAround(LatLng center, double radiusKm) {
  const kmPerDegLat = 111.0;
  final latDelta = radiusKm / kmPerDegLat;
  final cosLat = math.cos(center.latitude * math.pi / 180.0).abs();
  final lngDelta = radiusKm / (kmPerDegLat * math.max(0.01, cosLat));
  final swLat = (center.latitude - latDelta).clamp(-85.0, 85.0);
  final neLat = (center.latitude + latDelta).clamp(-85.0, 85.0);
  return LatLngBounds(
    southwest: LatLng(swLat, center.longitude - lngDelta),
    northeast: LatLng(neLat, center.longitude + lngDelta),
  );
}
