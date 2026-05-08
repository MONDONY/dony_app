import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

class MarkerUrgencyColor {
  MarkerUrgencyColor._();

  static const _orange = Color(0xFFF97316);

  static Color fromDeparture(DateTime departureDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final depDay = DateTime(
        departureDate.year, departureDate.month, departureDate.day);
    final diff = depDay.difference(today).inDays;

    if (diff < 0) return DonyColors.neutral400;
    if (diff < 3) return DonyColors.error;
    if (diff < 7) return _orange;
    if (diff < 14) return DonyColors.warning;
    return DonyColors.success;
  }
}
