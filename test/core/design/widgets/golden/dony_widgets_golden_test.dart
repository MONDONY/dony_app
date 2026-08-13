// Golden tests for representative Design System widgets.
//
// Captures visual snapshots in light and dark mode to catch color/layout
// regressions across theme changes.
//
// To regenerate goldens after intentional design changes:
//   flutter test --update-goldens test/core/design/widgets/golden/
//
// Font note: Google Fonts cannot be fetched in the test sandbox. The test theme
// is built identically to AppTheme but with the system text theme (Roboto) so
// that no network requests are issued. Color, shape, and spacing fidelity is
// preserved — only the typeface differs.

// Ces tests sont tagués `golden` et exclus de la CI : les images de référence
// sont produites sous macOS et le rendu de Roboto (hinting, anticrénelage)
// diffère sous Linux, ce qui produit ~0,03 % de pixels d'écart sans qu'aucun
// code n'ait changé. Ils restent pleinement valables en local :
//   flutter test test/core/design/widgets/golden/
@Tags(['golden'])
library;

import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rebuilds AppTheme with the same color scheme, card shape, button styles, etc.
/// but substitutes system fonts (no Google Fonts → no network calls in tests).
ThemeData _testTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;

  final cs = ColorScheme(
    brightness: brightness,
    primary: isLight ? DonyColors.primary : DonyColors.blueDark500,
    onPrimary: DonyColors.textOnBrand,
    primaryContainer: isLight ? DonyColors.primarySoft : DonyColors.blueDark50,
    onPrimaryContainer: isLight
        ? DonyColors.primaryHover
        : DonyColors.blueDark500,
    secondary: isLight ? DonyColors.accent : DonyColors.terraDark500,
    onSecondary: DonyColors.textOnBrand,
    secondaryContainer: isLight
        ? DonyColors.accentSoft
        : DonyColors.terraDark50,
    onSecondaryContainer: isLight
        ? DonyColors.terra700
        : DonyColors.terraDark500,
    surface: isLight ? DonyColors.surface : DonyColors.neutralDark100,
    onSurface: isLight ? DonyColors.textPrimary : DonyColors.neutralDark700,
    onSurfaceVariant: isLight
        ? DonyColors.textMuted
        : DonyColors.neutralDark500,
    surfaceContainerHighest: isLight
        ? DonyColors.neutral100
        : DonyColors.neutralDark200,
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

  // Use system text theme (Roboto) — identical structure to DonyTypography
  // but no Google Fonts network dependency.
  final tt = ThemeData(brightness: brightness).textTheme;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: cs,
    scaffoldBackgroundColor: isLight
        ? DonyColors.bgApp
        : DonyColors.neutralDark0,
    textTheme: tt.apply(bodyColor: cs.onSurface, displayColor: cs.onSurface),
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
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
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.lg),
        ),
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
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: cs.primary),
    ),
    dividerTheme: DividerThemeData(color: cs.outline, space: 1, thickness: 1),
  );
}

Widget _wrap(Widget child, {required Brightness brightness}) => MaterialApp(
  theme: _testTheme(brightness),
  home: Scaffold(
    body: Center(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  for (final brightness in Brightness.values) {
    final suffix = brightness == Brightness.light ? 'light' : 'dark';

    testWidgets('DonyCard — $suffix', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyCard(child: Text('Carte de test')),
          brightness: brightness,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dony_card_$suffix.png'),
      );
    });

    testWidgets('DonyButton primary — $suffix', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyButton(label: 'Action', onPressed: () {}),
          brightness: brightness,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dony_button_primary_$suffix.png'),
      );
    });

    testWidgets('DonyEmptyState — $suffix', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyEmptyState(
            title: 'Aucun élément',
            description: 'Reviens plus tard',
          ),
          brightness: brightness,
        ),
      );
      // pumpAndSettle lets flutter_animate finish entrance animations.
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dony_empty_state_$suffix.png'),
      );
    });

    testWidgets('DonyChip selected — $suffix', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DonyChip(label: 'Paris', selected: true, onTap: () {}),
          brightness: brightness,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dony_chip_selected_$suffix.png'),
      );
    });

    testWidgets('DonyStatusBanner success — $suffix', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DonyStatusBanner(
            type: DonyStatusBannerType.success,
            title: 'Succès',
            message: 'Opération réussie',
          ),
          brightness: brightness,
        ),
      );
      await tester.pump();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dony_status_banner_success_$suffix.png'),
      );
    });
  }
}
