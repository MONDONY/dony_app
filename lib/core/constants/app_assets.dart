enum EmptyStateContext { trips, profile }

enum PlaceholderType { driver, avatar }

abstract final class AppAssets {
  // ── Images ──────────────────────────────────────────────────────────────────
  // Logo bleu marine sur fond blanc — écrans clairs
  static const logo = 'assets/images/logo_dony.png';
  // Logo blanc sur fond transparent — écrans sombres/splash
  static const logoWhite = 'assets/images/icon_foreground.png';

  // ── Logos SVG (design system) ────────────────────────────────────────────
  // Wordmark couleur sur fond clair (usage général)
  static const logoSvg       = 'assets/logos/logo-dony.svg';
  // Wordmark blanc sur fond sombre ou coloré
  static const logoWhiteSvg  = 'assets/logos/logo-dony-white.svg';
  // App icon / mark seul (sans texte)
  static const logoMark      = 'assets/logos/logo-mark.svg';
  // Motif wax africain pour arrière-plans décoratifs
  static const patternWax    = 'assets/logos/pattern-wax.svg';

  // ── Onboarding ───────────────────────────────────────────────────────────
  static const onboarding1 = 'assets/images/onboarding-1-trips.png';
  static const onboarding2 = 'assets/images/onboarding-2-sharing.png';
  static const onboarding3 = 'assets/images/onboarding-3-security.png';

  // ── Empty states ─────────────────────────────────────────────────────────
  static const emptyStateTrips   = 'assets/images/empty-state-trips.png';
  static const emptyStateProfile = 'assets/images/empty-state-profile.png';

  // ── Placeholders ─────────────────────────────────────────────────────────
  static const placeholderDriver = 'assets/images/placeholder-driver.png';
  static const placeholderAvatar = 'assets/images/placeholder-avatar.png';

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String getLogoForBackground({required bool isDarkBackground}) =>
      isDarkBackground ? logoWhiteSvg : logoSvg;

  static String getOnboardingImage({required int step}) {
    switch (step) {
      case 1:
        return onboarding1;
      case 2:
        return onboarding2;
      case 3:
        return onboarding3;
      default:
        return onboarding1;
    }
  }

  static String getEmptyState({required EmptyStateContext context}) {
    switch (context) {
      case EmptyStateContext.trips:
        return emptyStateTrips;
      case EmptyStateContext.profile:
        return emptyStateProfile;
    }
  }

  static String getPlaceholder({required PlaceholderType type}) {
    switch (type) {
      case PlaceholderType.driver:
        return placeholderDriver;
      case PlaceholderType.avatar:
        return placeholderAvatar;
    }
  }
}
