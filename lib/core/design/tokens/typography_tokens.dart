import 'package:flutter/material.dart';

abstract final class DonyTypography {
  /// Familles embarquées, déclarées dans la table `fonts:` du pubspec.
  ///
  /// Elles passaient par google_fonts, qui téléchargeait chaque variante au
  /// premier lancement : sur un réseau faible l'échec remontait en erreur fatale
  /// non capturée et le texte s'affichait en police de repli (Sentry FLUTTER-2).
  ///
  /// Déclarer les fichiers en `assets:` aurait suffi à google_fonts, mais il les
  /// aurait alors chargés dans les tests de widgets aussi, de façon asynchrone :
  /// le rendu des tests changeait de police en cours de route et un test
  /// d'accessibilité qui échantillonne les pixels peints passait en local mais
  /// échouait en CI. Le moteur, lui, ne charge la table `fonts:` qu'en
  /// production ; les tests gardent leur police de repli déterministe.
  static const String fontDisplay = 'HankenGrotesk';
  static const String fontBody = 'PlusJakartaSans';
  static const String fontAccent = 'Caveat';

  static TextTheme get textTheme => const TextTheme(
    displayLarge: TextStyle(
      fontFamily: fontDisplay,
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.64,
      height: 1.10,
    ),
    displayMedium: TextStyle(
      fontFamily: fontDisplay,
      fontSize: 26,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.52,
      height: 1.15,
    ),
    displaySmall: TextStyle(
      fontFamily: fontDisplay,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.44,
      height: 1.20,
    ),
    headlineLarge: TextStyle(
      fontFamily: fontDisplay,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.22,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontFamily: fontDisplay,
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.18,
      height: 1.30,
    ),
    headlineSmall: TextStyle(
      fontFamily: fontDisplay,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    titleLarge: TextStyle(
      fontFamily: fontBody,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.35,
    ),
    titleMedium: TextStyle(
      fontFamily: fontBody,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.40,
    ),
    titleSmall: TextStyle(
      fontFamily: fontBody,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.40,
    ),
    bodyLarge: TextStyle(
      fontFamily: fontBody,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.50,
    ),
    bodyMedium: TextStyle(
      fontFamily: fontBody,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.50,
    ),
    bodySmall: TextStyle(
      fontFamily: fontBody,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.50,
    ),
    labelLarge: TextStyle(
      fontFamily: fontBody,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.20,
    ),
    labelMedium: TextStyle(
      fontFamily: fontBody,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.20,
      letterSpacing: 0.8,
    ),
    labelSmall: TextStyle(
      fontFamily: fontBody,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      height: 1.20,
      letterSpacing: 0.8,
    ),
  );

  // Accent cursif pour salutations et textes d'ambiance
  static TextStyle caveat({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) => TextStyle(
    fontFamily: fontAccent,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: 1.2,
  );
}
