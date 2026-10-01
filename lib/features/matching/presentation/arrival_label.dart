import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Heure d'arrivée suivie de « (+1 j) » quand le trajet arrive un autre jour
/// que le départ (vol de nuit, escale : FLUTTER-4E). Le même jour, l'heure
/// seule.
String arrivalTimeLabel(
  AppLocalizations l,
  String time, {
  required DateTime? departureDate,
  required DateTime? arrivalDate,
}) {
  if (departureDate == null || arrivalDate == null) return time;
  final days = DateUtils.dateOnly(
    arrivalDate,
  ).difference(DateUtils.dateOnly(departureDate)).inDays;
  if (days <= 0) return time;
  return l.tripArrivalDayOffsetSuffix(time, days);
}
