import 'package:flutter/material.dart';

abstract final class DonyShadow {
  // Ink-900 based shadows (10, 37, 64 hex = #0A2540 ≈ ink700)
  static const List<BoxShadow> xs = [
    BoxShadow(color: Color(0x0A0A2540), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0F0A2540), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0A0A2540), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x140A2540), blurRadius: 20, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A0A2540), blurRadius: 4, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x1F0A2540), blurRadius: 32, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> xl = [
    BoxShadow(color: Color(0x290A2540), blurRadius: 48, offset: Offset(0, 24)),
  ];

  // Branded shadows
  static const List<BoxShadow> brand = [
    BoxShadow(
      color: Color(0x3D0B5FFF), // blue500 @ 24%
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
  static const List<BoxShadow> accent = [
    BoxShadow(
      color: Color(0x38D96A3A), // terra500 @ 22%
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  // Convenience — card default
  static const List<BoxShadow> card = sm;
  // Convenience — bottom sheet / modal
  static const List<BoxShadow> sheet = lg;
}
