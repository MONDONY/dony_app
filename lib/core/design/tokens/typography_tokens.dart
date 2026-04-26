import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class DonyTypography {
  static TextTheme get textTheme => TextTheme(
    displayLarge:  GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w800, height: 1.10),
    displayMedium: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15),
    displaySmall:  GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, height: 1.20),
    headlineLarge:  GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, height: 1.25),
    headlineMedium: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, height: 1.30),
    headlineSmall:  GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35),
    titleLarge:  GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, height: 1.35),
    titleMedium: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, height: 1.40),
    titleSmall:  GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, height: 1.40),
    bodyLarge:  GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w400, height: 1.50),
    bodyMedium: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w400, height: 1.50),
    bodySmall:  GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w400, height: 1.50),
    labelLarge:  GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, height: 1.20),
    labelMedium: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, height: 1.20, letterSpacing: 0.8),
    labelSmall:  GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w600, height: 1.20, letterSpacing: 0.8),
  );
}
