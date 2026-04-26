import 'package:flutter/material.dart';

abstract final class DonyColors {
  static const blue50  = Color(0xFFE1F5FE);
  static const blue100 = Color(0xFFB3E5FC);
  static const blue200 = Color(0xFF81D4FA);
  static const blue300 = Color(0xFF29B6F6);
  static const blue400 = Color(0xFF0288D1); // PRIMARY ★
  static const blue500 = Color(0xFF0277BD);
  static const blue600 = Color(0xFF01579B);

  static const sand100 = Color(0xFFF5E6D3);
  static const sand300 = Color(0xFFD4A96A);
  static const sand400 = Color(0xFFC4956A); // SECONDARY ★
  static const sand500 = Color(0xFFA07040);

  static const white   = Color(0xFFFFFFFF);
  static const grey50  = Color(0xFFF7FBFF);
  static const grey100 = Color(0xFFE8F0F8);
  static const grey200 = Color(0xFFB3C8DC);
  static const grey400 = Color(0xFF78909C);
  static const grey600 = Color(0xFF546E7A);

  static const dark900 = Color(0xFF011627);
  static const dark850 = Color(0xFF012030);
  static const dark800 = Color(0xFF01294A);
  static const dark700 = Color(0xFF013A6B);

  static const success      = Color(0xFF2E7D32);
  static const successLight = Color(0xFFE8F5E9);
  static const error        = Color(0xFFC62828);
  static const errorDark    = Color(0xFFEF5350);
  static const errorLight   = Color(0xFFFFEBEE);
  static const warning      = Color(0xFFE65100);
  static const warningLight = Color(0xFFFFF3E0);
  static const info         = Color(0xFF1565C0);
  static const infoLight    = Color(0xFFE3F2FD);
}

// Extends ColorScheme with semantic tokens not present in Material 3.
extension DonyStatusColors on ColorScheme {
  Color get success      => DonyColors.success;
  Color get warning      => DonyColors.warning;
  Color get info         => DonyColors.info;
  Color get successLight => DonyColors.successLight;
  Color get warningLight => DonyColors.warningLight;
  Color get infoLight    => DonyColors.infoLight;
  Color get errorLight   => brightness == Brightness.light
      ? DonyColors.errorLight
      : DonyColors.error.withValues(alpha: 0.15);
  Color get errorDark => DonyColors.errorDark;
}
