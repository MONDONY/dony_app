import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/tokens/typography_tokens.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark  => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final cs = isLight
        ? ColorScheme.fromSeed(
            seedColor: DonyColors.blue400,
          ).copyWith(
            primary:          DonyColors.blue400,
            onPrimary:        DonyColors.white,
            primaryContainer: DonyColors.blue100,
            onPrimaryContainer: DonyColors.blue600,
            secondary:        DonyColors.sand400,
            onSecondary:      DonyColors.white,
            secondaryContainer: DonyColors.sand100,
            onSecondaryContainer: DonyColors.sand500,
            surface:          DonyColors.grey50,
            onSurface:        DonyColors.dark900,
            surfaceContainerHighest: DonyColors.grey100,
            outline:          DonyColors.grey200,
            outlineVariant:   DonyColors.grey100,
            error:            DonyColors.error,
            onError:          DonyColors.white,
          )
        : ColorScheme.fromSeed(
            seedColor: DonyColors.blue400,
            brightness: Brightness.dark,
          ).copyWith(
            primary:          DonyColors.blue300,
            onPrimary:        DonyColors.dark900,
            primaryContainer: DonyColors.dark700,
            onPrimaryContainer: DonyColors.blue100,
            secondary:        DonyColors.sand300,
            onSecondary:      DonyColors.dark900,
            secondaryContainer: DonyColors.dark800,
            onSecondaryContainer: DonyColors.sand100,
            surface:          DonyColors.dark900,
            onSurface:        DonyColors.grey50,
            surfaceContainerHighest: DonyColors.dark850,
            outline:          DonyColors.dark700,
            outlineVariant:   DonyColors.dark800,
            error:            DonyColors.errorDark,
            onError:          DonyColors.dark900,
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: DonyTypography.textTheme.apply(
        bodyColor: cs.onSurface,
        displayColor: cs.onSurface,
      ),
      scaffoldBackgroundColor: cs.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          side: BorderSide(color: cs.outline),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
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
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DonyRadius.md),
          borderSide: BorderSide(color: cs.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          textStyle: DonyTypography.textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          textStyle: DonyTypography.textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
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
    );
  }
}
