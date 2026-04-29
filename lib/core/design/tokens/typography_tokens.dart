import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class DonyTypography {
  static TextTheme get textTheme => TextTheme(
    displayLarge:  GoogleFonts.hankenGrotesk(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.64, height: 1.10),
    displayMedium: GoogleFonts.hankenGrotesk(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.52, height: 1.15),
    displaySmall:  GoogleFonts.hankenGrotesk(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.44, height: 1.20),
    headlineLarge:  GoogleFonts.hankenGrotesk(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.22, height: 1.25),
    headlineMedium: GoogleFonts.hankenGrotesk(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.18, height: 1.30),
    headlineSmall:  GoogleFonts.hankenGrotesk(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35),
    titleLarge:  GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, height: 1.35),
    titleMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, height: 1.40),
    titleSmall:  GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, height: 1.40),
    bodyLarge:  GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w400, height: 1.50),
    bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, height: 1.50),
    bodySmall:  GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w400, height: 1.50),
    labelLarge:  GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, height: 1.20),
    labelMedium: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, height: 1.20, letterSpacing: 0.8),
    labelSmall:  GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, height: 1.20, letterSpacing: 0.8),
  );

  // Accent cursif pour salutations et textes d'ambiance
  static TextStyle caveat({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) =>
      GoogleFonts.caveat(fontSize: fontSize, fontWeight: fontWeight, color: color, height: 1.2);
}
