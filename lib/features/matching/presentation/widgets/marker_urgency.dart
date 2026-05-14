import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

class MarkerUrgencyColor {
  MarkerUrgencyColor._();

  static const _orange = DonyColors.urgencyOrange;

  static Color fromDeparture(DateTime departureDate,
      {Brightness brightness = Brightness.light}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final depDay = DateTime(
        departureDate.year, departureDate.month, departureDate.day);
    final diff = depDay.difference(today).inDays;
    final isLight = brightness == Brightness.light;

    if (diff < 0) {
      return isLight ? DonyColors.neutral400 : DonyColors.neutralDark400;
    }
    if (diff < 3) {
      return isLight ? DonyColors.danger500 : DonyColors.dangerDark500;
    }
    if (diff < 7) return _orange;
    if (diff < 14) {
      return isLight ? DonyColors.warning500 : DonyColors.warningDark500;
    }
    return isLight ? DonyColors.success500 : DonyColors.successDark500;
  }
}
