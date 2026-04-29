import 'package:flutter/material.dart';

abstract final class DonyDuration {
  static const micro = Duration(milliseconds: 150);
  static const base  = Duration(milliseconds: 220);
  static const slow  = Duration(milliseconds: 320);
  static const page  = Duration(milliseconds: 480);

  // Int form for flutter_animate (.ms extension)
  static const microMs = 150;
  static const baseMs  = 220;
  static const slowMs  = 320;
  static const pageMs  = 480;
}

abstract final class DonyCurve {
  static const easeOut   = Cubic(0.2, 0.8, 0.2, 1.0);
  static const easeInOut = Cubic(0.5, 0.0, 0.2, 1.0);
  static const spring    = Curves.easeOutCubic;
  static const enter     = Curves.easeOutCubic;
  static const exit      = Curves.easeInCubic;

  // Stagger delay between list items (ms per index)
  static const staggerMs = 60;
}
