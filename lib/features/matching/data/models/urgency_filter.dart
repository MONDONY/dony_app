import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

enum UrgencyFilter {
  veryUrgent(color: DonyColors.urgencyRed),
  urgent(color: DonyColors.urgencyOrange),
  soon(color: DonyColors.urgencyAmber),
  later(color: DonyColors.urgencyGreen);

  const UrgencyFilter({required this.color});

  final Color color;

  /// Plage de dates de départ couverte par ce filtre, bornes incluses, à la
  /// journée : la même que [matches], traduite pour la recherche serveur.
  /// [to] est nul pour [later], sans borne haute.
  ///
  /// Le filtre était appliqué au seul écran, sur la page déjà chargée : le
  /// compteur du composeur et celui de l'accueil gardaient le total serveur
  /// sans filtre, et les trajets urgents des pages suivantes n'apparaissaient
  /// jamais (Sentry FLUTTER-MH, FLUTTER-JG).
  ({DateTime from, DateTime? to}) departureRange([DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    DateTime day(int offset) =>
        DateTime(today.year, today.month, today.day + offset);
    switch (this) {
      case UrgencyFilter.veryUrgent:
        return (from: today, to: day(2));
      case UrgencyFilter.urgent:
        return (from: day(3), to: day(6));
      case UrgencyFilter.soon:
        return (from: day(7), to: day(13));
      case UrgencyFilter.later:
        return (from: day(14), to: null);
    }
  }

  bool matches(DateTime departureDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dep = DateTime(
      departureDate.year,
      departureDate.month,
      departureDate.day,
    );
    final diff = dep.difference(today).inDays;
    switch (this) {
      case UrgencyFilter.veryUrgent:
        return diff >= 0 && diff < 3;
      case UrgencyFilter.urgent:
        return diff >= 3 && diff < 7;
      case UrgencyFilter.soon:
        return diff >= 7 && diff < 14;
      case UrgencyFilter.later:
        return diff >= 14;
    }
  }
}
