import 'package:dony/core/design/theme/a11y_theme_options.dart';
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/tokens/typography_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
  static ThemeData light({A11yThemeOptions a11y = const A11yThemeOptions()}) =>
      _build(Brightness.light, a11y);

  static ThemeData dark({A11yThemeOptions a11y = const A11yThemeOptions()}) =>
      _build(Brightness.dark, a11y);

  static ThemeData _build(Brightness brightness, A11yThemeOptions a11y) {
    final isLight = brightness == Brightness.light;
    final hc = a11y.highContrast;

    final cs = ColorScheme(
      brightness: brightness,
      primary: hc
          ? (isLight ? DonyColors.primaryHc : DonyColors.primaryHcDark)
          : (isLight ? DonyColors.primary : DonyColors.blueDark500),
      // En haut contraste sombre, primary est un bleu clair : un libellé blanc
      // n'y ferait que 2.04:1. Le noir y monte à 10.30:1.
      onPrimary: hc && !isLight
          ? DonyColors.onBrandHcDark
          : DonyColors.textOnBrand,
      primaryContainer: isLight ? DonyColors.primarySoft : DonyColors.blueDark50,
      onPrimaryContainer: isLight ? DonyColors.primaryHover : DonyColors.blueDark500,
      secondary: isLight ? DonyColors.accent : DonyColors.terraDark500,
      onSecondary: DonyColors.textOnBrand,
      secondaryContainer: isLight ? DonyColors.accentSoft : DonyColors.terraDark50,
      onSecondaryContainer: isLight ? DonyColors.terra700 : DonyColors.terraDark500,
      surface: hc
          ? (isLight ? DonyColors.surfaceHc : DonyColors.surfaceHcDark)
          : (isLight ? DonyColors.surface : DonyColors.neutralDark100),
      onSurface: hc
          ? (isLight ? DonyColors.textPrimaryHc : DonyColors.textPrimaryHcDark)
          : (isLight ? DonyColors.textPrimary : DonyColors.neutralDark700),
      onSurfaceVariant: hc
          ? (isLight ? DonyColors.textMutedHc : DonyColors.textMutedHcDark)
          : (isLight ? DonyColors.textMuted : DonyColors.neutralDark500),
      surfaceContainerHighest: isLight ? DonyColors.neutral100 : DonyColors.neutralDark200,
      surfaceContainerLow: isLight ? DonyColors.bgApp : DonyColors.neutralDark50,
      outline: hc
          ? (isLight ? DonyColors.borderDefaultHc : DonyColors.borderDefaultHcDark)
          : (isLight ? DonyColors.borderDefault : DonyColors.neutralDark300),
      outlineVariant: isLight ? DonyColors.neutral100 : DonyColors.neutralDark200,
      error: isLight ? DonyColors.danger500 : DonyColors.dangerDark500,
      // Le rouge d'erreur du thème sombre est clair : un libellé blanc dessus
      // ne fait que 3.55:1. Le noir y monte à 5.91:1. Contrairement à
      // `onPrimary`, ce rôle n'est posé que sur des aplats d'erreur, jamais
      // sur un dégradé, donc la bascule est sans risque.
      onError: isLight ? DonyColors.textOnBrand : DonyColors.onBrandHcDark,
      errorContainer: isLight ? DonyColors.danger50 : DonyColors.dangerDark50,
      onErrorContainer: isLight ? DonyColors.danger500 : DonyColors.dangerDark500,
      shadow: isLight ? DonyColors.shadow : DonyColors.shadowDark,
      inverseSurface: isLight ? DonyColors.ink800 : DonyColors.neutral0,
      onInverseSurface: isLight ? DonyColors.neutral0 : DonyColors.textPrimary,
    );

    final scaffoldBg = hc
        ? (isLight ? DonyColors.bgAppHc : DonyColors.bgAppHcDark)
        : (isLight ? DonyColors.bgApp : DonyColors.neutralDark0);

    // Bordures épaissies en haut contraste : la bordure par défaut à 1 px sur
    // neutral200 est quasi invisible pour une basse vision.
    final borderWidth = hc ? 1.5 : 1.0;

    // Le contour d'un champ est un composant d'interface, pas une décoration :
    // il lui faut 3:1. `cs.outline` n'y arrive pas et ne le doit pas, il sert
    // aussi aux séparateurs.
    final inputBorderColor = hc
        ? cs.outline
        : (isLight ? DonyColors.borderInput : DonyColors.borderInputDark);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: DonyTypography.textTheme.apply(
        bodyColor: cs.onSurface,
        displayColor: cs.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: DonyTypography.textTheme.headlineMedium?.copyWith(
          color: cs.onSurface,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.card),
          side: BorderSide(color: cs.outline, width: borderWidth),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: inputBorderColor, width: borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: inputBorderColor, width: borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.error),
        ),
        labelStyle: DonyTypography.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        // Un placeholder est du texte, donc 4.5:1. neutral400 n'en donnait que
        // 2.54:1 sur blanc ; textSubtle (neutral500) monte à 4.71:1.
        hintStyle: DonyTypography.textTheme.bodyMedium?.copyWith(
          color: isLight ? DonyColors.textSubtle : DonyColors.neutralDark400,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          // Pas `cs.onPrimary` : ce rôle sert aussi de texte sur des dégradés
          // de marque allant du bleu très sombre au bleu clair, où le noir
          // serait illisible. Ici le fond est l'aplat `cs.primary`, connu, et
          // en thème sombre il est trop clair pour un libellé blanc (3.28:1).
          foregroundColor:
              isLight ? cs.onPrimary : DonyColors.onBrandHcDark,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
          textStyle: DonyTypography.textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
          side: BorderSide(color: cs.outline, width: borderWidth),
          textStyle: DonyTypography.textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: DonyTypography.textTheme.labelLarge?.copyWith(
            decoration: a11y.underlineLinks
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outline,
        space: 1,
        thickness: borderWidth,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sm),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        thumbColor: cs.primary,
        inactiveTrackColor: cs.outline,
        overlayColor: cs.primary.withValues(alpha: 0.12),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(),
      ),
      pageTransitionsTheme: a11y.reduceMotion
          ? const PageTransitionsTheme(builders: {
              TargetPlatform.android: _NoTransitionsBuilder(),
              TargetPlatform.iOS: _NoTransitionsBuilder(),
            })
          : const PageTransitionsTheme(),
    );
  }
}

/// Transition de page instantanée, utilisée quand la réduction du mouvement
/// est active. Les animations de navigation ne sont pas couvertes par
/// `MediaQuery.disableAnimations` sur toutes les plateformes, il faut donc
/// les neutraliser explicitement.
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}
