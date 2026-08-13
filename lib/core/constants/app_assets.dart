abstract final class AppAssets {
  // ── Mot-logo Yadony ─────────────────────────────────────────────────────
  // Un seul fichier haute résolution (1081×295), identique à celui du splash
  // native. Aucune déclinaison sur fond sombre n'existe encore, d'où les deux
  // constantes pointant sur la même image.
  static const logoBlueOrange = 'assets/logos/logo-yadony.png'; // fond clair
  static const logoWhiteOrange = 'assets/logos/logo-yadony.png'; // fond sombre

  // Aliases sémantiques
  static const logo = logoBlueOrange;
  static const logoWhite = logoWhiteOrange;

  static String getLogoForBackground({required bool isDarkBackground}) =>
      isDarkBackground ? logoWhiteOrange : logoBlueOrange;
}
