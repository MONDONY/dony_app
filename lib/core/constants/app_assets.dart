abstract final class AppAssets {
  // ── Logos ────────────────────────────────────────────────────────────────
  // Texte bleu + accent orange — fonds clairs (usage général)
  static const logoBlueOrange      = 'assets/logos/logo-blue-orange.svg';
  // Texte bleu + accent orange + halo — splash / hero
  static const logoBlueOrangeGlow  = 'assets/logos/logo-blue-orange-glow.svg';
  // Texte noir + accent bleu — fonds clairs alternatifs
  static const logoBlackBlue       = 'assets/logos/logo-black-blue.svg';
  // Texte noir + accent orange — fonds clairs alternatifs
  static const logoBlackOrange     = 'assets/logos/logo-black-orange.svg';
  // Texte blanc + accent bleu — fonds sombres
  static const logoWhiteBlue       = 'assets/logos/logo-white-blue.svg';
  // Texte blanc + accent orange — fonds sombres / splash
  static const logoWhiteOrange     = 'assets/logos/logo-white-orange.svg';
  // Motif wax africain pour fonds décoratifs
  static const patternWax          = 'assets/logos/pattern-wax.svg';

  // Aliases sémantiques
  static const logo      = logoBlueOrange;   // fond clair
  static const logoWhite = logoWhiteOrange;  // fond sombre / splash

  // ── Helper ───────────────────────────────────────────────────────────────
  static String getLogoForBackground({required bool isDarkBackground}) =>
      isDarkBackground ? logoWhiteOrange : logoBlueOrange;
}