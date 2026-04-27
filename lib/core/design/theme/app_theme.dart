import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/tokens/typography_tokens.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary:          DonyColors.green400,
      onPrimary:        DonyColors.white,
      primaryContainer: DonyColors.green50,
      onPrimaryContainer: DonyColors.green600,
      secondary:        DonyColors.terra500,
      onSecondary:      DonyColors.white,
      secondaryContainer: DonyColors.terra50,
      onSecondaryContainer: DonyColors.terra700,
      surface:          DonyColors.white,
      onSurface:        DonyColors.ink900,
      surfaceContainerHighest: DonyColors.grey100,
      surfaceContainerLow: DonyColors.bg,
      outline:          DonyColors.grey200,
      outlineVariant:   DonyColors.grey100,
      error:            DonyColors.error,
      onError:          DonyColors.white,
      shadow:           Color(0x1A0D1B2A),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: DonyColors.bg,
      textTheme: DonyTypography.textTheme.apply(
        bodyColor: DonyColors.ink900,
        displayColor: DonyColors.ink900,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: DonyColors.white,
        foregroundColor: DonyColors.ink900,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: DonyTypography.textTheme.headlineMedium?.copyWith(
          color: DonyColors.ink900,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: DonyColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.card),
          side: const BorderSide(color: DonyColors.grey200),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DonyColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.grey200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.grey200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.green400, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: const BorderSide(color: DonyColors.error),
        ),
        labelStyle: DonyTypography.textTheme.bodyMedium?.copyWith(color: DonyColors.grey400),
        hintStyle: DonyTypography.textTheme.bodyMedium?.copyWith(color: DonyColors.grey400),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DonyColors.green400,
          foregroundColor: DonyColors.white,
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
          foregroundColor: DonyColors.ink900,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
          ),
          side: const BorderSide(color: DonyColors.grey200),
          textStyle: DonyTypography.textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DonyColors.green400,
          textStyle: DonyTypography.textTheme.labelLarge,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: DonyColors.grey200,
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
        activeTrackColor: DonyColors.green400,
        thumbColor: DonyColors.green400,
        inactiveTrackColor: DonyColors.grey200,
        overlayColor: DonyColors.green400.withValues(alpha: 0.12),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(),
      ),
    );
  }
}
