import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Palette dony
const kGreenPrimary  = Color(0xFF1A6B3C);
const kGreenDark     = Color(0xFF134F2D);
const kGreenAccent   = Color(0xFF4CAF7D);
const kGreenLight    = Color(0xFFE8F5EE);
const kBackground    = Color(0xFFF4F6F8);
const kSurface       = Color(0xFFFFFFFF);
const kTextPrimary   = Color(0xFF0D1B2A);
const kTextSecondary = Color(0xFF6B7A8D);
const kTextHint      = Color(0xFFADB5BD);
const kBorder        = Color(0xFFE9ECEF);
const kError         = Color(0xFFE53935);
const kWarning       = Color(0xFFF59E0B);
const kSuccess       = Color(0xFF16A34A);

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kGreenPrimary,
    primary: kGreenPrimary,
    surface: kSurface,
    error: kError,
  ),
  scaffoldBackgroundColor: kBackground,
  textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
    displayLarge: GoogleFonts.plusJakartaSans(
      fontSize: 32, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5,
    ),
    displayMedium: GoogleFonts.plusJakartaSans(
      fontSize: 26, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.3,
    ),
    headlineLarge: GoogleFonts.plusJakartaSans(
      fontSize: 22, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.2,
    ),
    headlineMedium: GoogleFonts.plusJakartaSans(
      fontSize: 18, fontWeight: FontWeight.w600, color: kTextPrimary,
    ),
    titleLarge: GoogleFonts.plusJakartaSans(
      fontSize: 16, fontWeight: FontWeight.w600, color: kTextPrimary,
    ),
    titleMedium: GoogleFonts.plusJakartaSans(
      fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary,
    ),
    bodyLarge: GoogleFonts.plusJakartaSans(
      fontSize: 16, fontWeight: FontWeight.w400, color: kTextPrimary,
    ),
    bodyMedium: GoogleFonts.plusJakartaSans(
      fontSize: 14, fontWeight: FontWeight.w400, color: kTextSecondary,
    ),
    bodySmall: GoogleFonts.plusJakartaSans(
      fontSize: 12, fontWeight: FontWeight.w400, color: kTextSecondary,
    ),
    labelLarge: GoogleFonts.plusJakartaSans(
      fontSize: 15, fontWeight: FontWeight.w600, color: kSurface,
    ),
  ),
  appBarTheme: AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    backgroundColor: kSurface,
    foregroundColor: kTextPrimary,
    titleTextStyle: GoogleFonts.plusJakartaSans(
      fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kGreenPrimary,
      foregroundColor: kSurface,
      minimumSize: const Size.fromHeight(52),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      textStyle: GoogleFonts.plusJakartaSans(
        fontSize: 15, fontWeight: FontWeight.w600,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kGreenPrimary,
      minimumSize: const Size.fromHeight(52),
      side: const BorderSide(color: kGreenPrimary, width: 1.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      textStyle: GoogleFonts.plusJakartaSans(
        fontSize: 15, fontWeight: FontWeight.w600,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: kSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kGreenPrimary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kError),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    labelStyle: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 14),
    hintStyle: GoogleFonts.plusJakartaSans(color: kTextHint, fontSize: 14),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: kSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: kBorder),
    ),
    margin: EdgeInsets.zero,
  ),
  dividerTheme: const DividerThemeData(
    color: kBorder,
    space: 1,
    thickness: 1,
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    contentTextStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
  ),
);
