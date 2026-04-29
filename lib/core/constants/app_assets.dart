abstract final class AppAssets {
  // ── Logos PNG (1x — Flutter charge 2x/3x automatiquement) ───────────────
  static const logoBlueOrange  = 'assets/logos/logo-blue-orange.png';   // fond clair
  static const logoWhiteOrange = 'assets/logos/logo-white-orange.png';  // fond sombre

  // Aliases sémantiques
  static const logo      = logoBlueOrange;
  static const logoWhite = logoWhiteOrange;

  static String getLogoForBackground({required bool isDarkBackground}) =>
      isDarkBackground ? logoWhiteOrange : logoBlueOrange;
}
