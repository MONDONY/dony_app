import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

enum UrgencyFilter {
  veryUrgent(color: DonyColors.urgencyRed),
  urgent(color: DonyColors.urgencyOrange),
  soon(color: DonyColors.urgencyAmber),
  later(color: DonyColors.urgencyGreen);

  const UrgencyFilter({required this.color});

  final Color color;

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
