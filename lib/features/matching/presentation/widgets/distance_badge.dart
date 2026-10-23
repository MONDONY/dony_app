import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:geolocator/geolocator.dart';

/// Retourne un badge formaté "CDG · 3 km" ou null si indisponible.
String? buildDistanceBadge(
  AnnouncementModel announcement,
  ({double lat, double lng})? userPos,
) {
  if (userPos == null) return null;
  final pickup = announcement.pickupAddress;
  if (pickup == null) return null;

  final distanceM = Geolocator.distanceBetween(
    userPos.lat,
    userPos.lng,
    pickup.lat,
    pickup.lng,
  );
  final distanceKm = (distanceM / 1000).round();

  final allMatches = RegExp(r'\b([A-Z]{3})\b').allMatches(pickup.label);
  final locationCode = allMatches.isNotEmpty
      ? allMatches.last.group(1)!
      : pickup.label.split(' ').first;

  final distanceLabel = distanceKm == 0
      ? '< 1 km' // i18n-ignore — format sans mot (unité identique fr/en)
      : '$distanceKm km'; // i18n-ignore — format sans mot
  return '$locationCode · $distanceLabel'; // i18n-ignore — format, séparateur
}
