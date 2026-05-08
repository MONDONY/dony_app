import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/tokens/typography_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppTheme {
  static ThemeData get light => _build();

  static ThemeData _build() {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary:              DonyColors.primary,        // blue500 #0B5FFF
      onPrimary:            DonyColors.textOnBrand,
      primaryContainer:     DonyColors.primarySoft,    // blue50
      onPrimaryContainer:   DonyColors.primaryHover,   // blue600
      secondary:            DonyColors.accent,         // terra500
      onSecondary:          DonyColors.textOnBrand,
      secondaryContainer:   DonyColors.accentSoft,     // terra50
      onSecondaryContainer: DonyColors.terra700,
      surface:              DonyColors.surface,        // white
      onSurface:            DonyColors.textPrimary,    // ink800
      surfaceContainerHighest: DonyColors.neutral100,
      surfaceContainerLow:  DonyColors.bgApp,          // neutral50
      outline:              DonyColors.borderDefault,  // neutral200
      outlineVariant:       DonyColors.neutral100,
      error:                DonyColors.danger500,
      onError:              DonyColors.textOnBrand,
      shadow:               DonyColors.shadow,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: DonyColors.bgApp,
      textTheme: DonyTypography.textTheme.apply(
        bodyColor: DonyColors.textPrimary,
        displayColor: DonyColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: DonyColors.surface,
        foregroundColor: DonyColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: DonyTypography.textTheme.headlineMedium?.copyWith(
          color: DonyColors.textPrimary,
        ),
        // Barre nav transparente sur tous les écrans avec AppBar
        systemOverlayStyle: const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: DonyColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.card),
          side: const BorderSide(color: DonyColors.borderDefault),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DonyColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.borderFocus, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.danger500),
        ),
        labelStyle: DonyTypography.textTheme.bodyMedium?.copyWith(color: DonyColors.textMuted),
        hintStyle: DonyTypography.textTheme.bodyMedium?.copyWith(color: DonyColors.neutral400),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DonyColors.primary,
          foregroundColor: DonyColors.textOnBrand,
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
          foregroundColor: DonyColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
          side: const BorderSide(color: DonyColors.borderDefault),
          textStyle: DonyTypography.textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DonyColors.primary,
          textStyle: DonyTypography.textTheme.labelLarge,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: DonyColors.borderDefault,
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
        activeTrackColor: DonyColors.primary,
        thumbColor: DonyColors.primary,
        inactiveTrackColor: DonyColors.borderDefault,
        overlayColor: DonyColors.primary.withValues(alpha: 0.12),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(),
      ),
    );
  }
}
