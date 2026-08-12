import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

enum UrgencyFilter {
  veryUrgent(color: DonyColors.urgencyRed,    label: '< 3j', tooltip: 'Départ dans moins de 3 jours'),
  urgent(color: DonyColors.urgencyOrange,      label: '3–7j', tooltip: 'Départ dans 3 à 7 jours'),
  soon(color: DonyColors.urgencyAmber,         label: '7–14j', tooltip: 'Départ dans 7 à 14 jours'),
  later(color: DonyColors.urgencyGreen,        label: '14j+', tooltip: 'Départ dans plus de 14 jours');

  const UrgencyFilter({
    required this.color,
    required this.label,
    required this.tooltip,
  });

  final Color color;
  final String label;
  final String tooltip;

  bool matches(DateTime departureDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dep = DateTime(departureDate.year, departureDate.month, departureDate.day);
    final diff = dep.difference(today).inDays;
    switch (this) {
      case UrgencyFilter.veryUrgent: return diff >= 0 && diff < 3;
      case UrgencyFilter.urgent:     return diff >= 3 && diff < 7;
      case UrgencyFilter.soon:       return diff >= 7 && diff < 14;
      case UrgencyFilter.later:      return diff >= 14;
    }
  }
}
