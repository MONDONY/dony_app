import 'package:flutter/material.dart';

abstract final class DonyColors {
  // Primary — vert forêt (confiance)
  static const green50  = Color(0xFFE8F5EE);
  static const green100 = Color(0xFFBBDFCC);
  static const green200 = Color(0xFF8FCAAB);
  static const green300 = Color(0xFF4CAF7D);
  static const green400 = Color(0xFF1A6B3C);  // PRIMARY ★
  static const green500 = Color(0xFF145430);
  static const green600 = Color(0xFF0E3D23);
  static const green700 = Color(0xFF0A2E1A);
  static const greenDark = Color(0xFF0E2318); // stats card bg

  // Terracotta — accent chaud africain
  static const terra50  = Color(0xFFFCF0E9);
  static const terra300 = Color(0xFFEA9468);
  static const terra500 = Color(0xFFD96A3A);  // ACCENT ★
  static const terra700 = Color(0xFF93421B);

  // Surface / background
  static const white      = Color(0xFFFFFFFF);
  static const bg         = Color(0xFFF4F5F0);
  static const surfaceWarm= Color(0xFFF7F3ED);
  static const grey50     = Color(0xFFFAFAF8);
  static const grey100    = Color(0xFFF2F1ED);
  static const grey200    = Color(0xFFE9ECEF);
  static const grey300    = Color(0xFFD2CDC2);
  static const grey400    = Color(0xFF6B7A8D);
  static const grey500    = Color(0xFF797367);

  // Ink (texte principal)
  static const ink900 = Color(0xFF0D1B2A);  // text primary ★
  static const ink800 = Color(0xFF1A2B3C);
  static const ink700 = Color(0xFF253545);

  // Shadow
  static const shadow = Color(0x1A0D1B2A);  // ink900 @ 10%

  // Semantic
  static const success      = Color(0xFF16A34A);
  static const successLight = Color(0xFFE8F5EE);
  static const error        = Color(0xFFE53935);
  static const errorLight   = Color(0xFFFFEBEE);
  static const warning      = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFFF3E0);
  static const info         = Color(0xFF1565C0);
  static const infoLight    = Color(0xFFE3F2FD);

  // Avatar supplement
  static const purple = Color(0xFF6A1B9A);
  static const teal   = Color(0xFF00695C);
}

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
}
