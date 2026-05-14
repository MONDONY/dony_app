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

  // ─── Branded shadows — boutons gradient ────────────────────────────────────

  // Primary blue (light)
  static const List<BoxShadow> brand = [
    BoxShadow(
      color: Color(0x3D0B5FFF), // blue500 @ 24%
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x1A0B5FFF), // blue500 @ 10%
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  // Primary blue (dark)
  static const List<BoxShadow> brandDark = [
    BoxShadow(
      color: Color(0x4D4D8AFF), // blueDark500 @ 30%
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  // Success green (light)
  static const List<BoxShadow> success = [
    BoxShadow(
      color: Color(0x380E8A5F), // success500 @ 22%
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  // Success green (dark)
  static const List<BoxShadow> successDark = [
    BoxShadow(
      color: Color(0x3D2DA677), // successDark500 @ 24%
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  // Danger red (light)
  static const List<BoxShadow> danger = [
    BoxShadow(
      color: Color(0x38D9342B), // danger500 @ 22%
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  // Danger red (dark)
  static const List<BoxShadow> dangerDark = [
    BoxShadow(
      color: Color(0x3DEF5048), // dangerDark500 @ 24%
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  // Terra accent
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
  // Convenience — sticky bottom bar (shadow upward)
  static const List<BoxShadow> sticky = [
    BoxShadow(color: Color(0x0A0A2540), blurRadius: 8, offset: Offset(0, -2)),
  ];
}

/// Alias for backwards-compatibility with widgets using DonyShadows.
typedef DonyShadows = DonyShadow;
