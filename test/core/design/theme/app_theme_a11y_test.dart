import 'dart:math' as math;

import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ratio de contraste WCAG entre deux couleurs opaques.
double contrastRatio(Color a, Color b) {
  double lum(Color c) {
    double channel(double v) {
      final s = v / 255.0;
      return s <= 0.03928
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(c.r * 255) +
        0.7152 * channel(c.g * 255) +
        0.0722 * channel(c.b * 255);
  }

  final la = lum(a), lb = lum(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppTheme — variantes d\'accessibilité', () {
    testWidgets(
      'sans options, le thème clair est inchangé sur les couleurs clés',
      (tester) async {
        final normal = AppTheme.light();
        expect(normal.colorScheme.primary, DonyColors.primary);
        expect(normal.colorScheme.onSurface, DonyColors.textPrimary);
      },
    );

    testWidgets('le contraste élevé change le texte et les bordures en clair', (
      tester,
    ) async {
      final hc = AppTheme.light(
        a11y: const A11yThemeOptions(highContrast: true),
      );
      final normal = AppTheme.light();
      expect(hc.colorScheme.onSurface, isNot(normal.colorScheme.onSurface));
      expect(hc.colorScheme.outline, isNot(normal.colorScheme.outline));
    });

    testWidgets('le texte principal contrasté atteint 7:1 sur la surface', (
      tester,
    ) async {
      final hc = AppTheme.light(
        a11y: const A11yThemeOptions(highContrast: true),
      );
      final ratio = contrastRatio(
        hc.colorScheme.onSurface,
        hc.colorScheme.surface,
      );
      expect(ratio, greaterThanOrEqualTo(7.0));
    });

    testWidgets('le texte secondaire contrasté dépasse 4.5:1 sur la surface', (
      tester,
    ) async {
      final hc = AppTheme.light(
        a11y: const A11yThemeOptions(highContrast: true),
      );
      final ratio = contrastRatio(
        hc.colorScheme.onSurfaceVariant,
        hc.colorScheme.surface,
      );
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    testWidgets('le contraste élevé fonctionne aussi en sombre', (
      tester,
    ) async {
      final hc = AppTheme.dark(
        a11y: const A11yThemeOptions(highContrast: true),
      );
      final ratio = contrastRatio(
        hc.colorScheme.onSurface,
        hc.colorScheme.surface,
      );
      expect(ratio, greaterThanOrEqualTo(7.0));
    });

    testWidgets('le soulignement des liens s\'applique au textButtonTheme', (
      tester,
    ) async {
      final off = AppTheme.light();
      final on = AppTheme.light(
        a11y: const A11yThemeOptions(underlineLinks: true),
      );
      TextDecoration? deco(ThemeData t) =>
          t.textButtonTheme.style?.textStyle?.resolve({})?.decoration;
      expect(deco(off), anyOf(isNull, TextDecoration.none));
      expect(deco(on), TextDecoration.underline);
    });

    testWidgets('la réduction du mouvement supprime les transitions de page', (
      tester,
    ) async {
      final off = AppTheme.light();
      final on = AppTheme.light(
        a11y: const A11yThemeOptions(reduceMotion: true),
      );
      expect(
        on.pageTransitionsTheme.builders[TargetPlatform.android],
        isNot(off.pageTransitionsTheme.builders[TargetPlatform.android]),
      );
      expect(
        on.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<PageTransitionsBuilder>(),
      );
    });

    testWidgets('les bordures contrastées sont plus épaisses sur les champs', (
      tester,
    ) async {
      final on = AppTheme.light(
        a11y: const A11yThemeOptions(highContrast: true),
      );
      final border =
          on.inputDecorationTheme.enabledBorder as OutlineInputBorder;
      expect(border.borderSide.width, greaterThanOrEqualTo(1.5));
    });
  });
}
