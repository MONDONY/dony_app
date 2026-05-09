import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/tokens/typography_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final cs = ColorScheme(
      brightness: brightness,
      primary: isLight ? DonyColors.primary : DonyColors.blueDark500,
      onPrimary: DonyColors.textOnBrand,
      primaryContainer: isLight ? DonyColors.primarySoft : DonyColors.blueDark50,
      onPrimaryContainer: isLight ? DonyColors.primaryHover : DonyColors.blueDark500,
      secondary: isLight ? DonyColors.accent : DonyColors.terraDark500,
      onSecondary: DonyColors.textOnBrand,
      secondaryContainer: isLight ? DonyColors.accentSoft : DonyColors.terraDark50,
      onSecondaryContainer: isLight ? DonyColors.terra700 : DonyColors.terraDark500,
      surface: isLight ? DonyColors.surface : DonyColors.neutralDark100,
      onSurface: isLight ? DonyColors.textPrimary : DonyColors.neutralDark700,
      onSurfaceVariant: isLight ? DonyColors.textMuted : DonyColors.neutralDark500,
      surfaceContainerHighest: isLight ? DonyColors.neutral100 : DonyColors.neutralDark200,
      surfaceContainerLow: isLight ? DonyColors.bgApp : DonyColors.neutralDark50,
      outline: isLight ? DonyColors.borderDefault : DonyColors.neutralDark300,
      outlineVariant: isLight ? DonyColors.neutral100 : DonyColors.neutralDark200,
      error: isLight ? DonyColors.danger500 : DonyColors.dangerDark500,
      onError: DonyColors.textOnBrand,
      errorContainer: isLight ? DonyColors.danger50 : DonyColors.dangerDark50,
      onErrorContainer: isLight ? DonyColors.danger500 : DonyColors.dangerDark500,
      shadow: isLight ? DonyColors.shadow : DonyColors.shadowDark,
      inverseSurface: isLight ? DonyColors.ink800 : DonyColors.neutral0,
      onInverseSurface: isLight ? DonyColors.neutral0 : DonyColors.textPrimary,
    );

    final scaffoldBg = isLight ? DonyColors.bgApp : DonyColors.neutralDark0;

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
          side: BorderSide(color: cs.outline),
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
          borderSide: BorderSide(color: cs.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.outline),
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
        hintStyle: DonyTypography.textTheme.bodyMedium?.copyWith(
          color: isLight ? DonyColors.neutral400 : DonyColors.neutralDark400,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
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
          side: BorderSide(color: cs.outline),
          textStyle: DonyTypography.textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: DonyTypography.textTheme.labelLarge,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outline,
        space: 1,
        thickness: 1,
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
    );
  }
}
