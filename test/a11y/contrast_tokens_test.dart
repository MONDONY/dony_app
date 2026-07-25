import 'dart:math' as math;

import 'package:dony/core/design/accessibility_scope.dart';
import 'package:dony/core/design/theme/a11y_theme_options.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/widgets/dony_avatar.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Luminance relative WCAG 2.1, formule 1.4.3.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// Ratio de contraste entre deux couleurs opaques.
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Échoue avec le ratio mesuré, sinon un écart de 0.01 se lit « false ».
void expectContrast(Color fg, Color bg, double min, String label) {
  final r = contrastRatio(fg, bg);
  expect(
    r,
    greaterThanOrEqualTo(min),
    reason: '$label : ${r.toStringAsFixed(2)}:1, minimum requis $min:1',
  );
}

void main() {
  group('contrastRatio', () {
    test('donne les bornes connues', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21.0, 0.01),
      );
      expect(
        contrastRatio(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)),
        closeTo(1.0, 0.01),
      );
      expectSymmetry();
    });
  });

  group('tokens corrigés au lot 2a', () {
    test('le placeholder des champs sombres est lisible', () {
      // hintStyle du thème sombre. C'est du texte, donc 4.5:1.
      expectContrast(
        DonyColors.neutralDark400,
        DonyColors.neutralDark100,
        4.5,
        'placeholder sur surface sombre',
      );
      expectContrast(
        DonyColors.neutralDark400,
        DonyColors.neutralDark0,
        4.5,
        'placeholder sur fond app sombre',
      );
    });

    test('le texte sur conteneur primaire sombre est lisible', () {
      expectContrast(
        DonyColors.blueDark500,
        DonyColors.blueDark50,
        4.5,
        'onPrimaryContainer sur primaryContainer, sombre',
      );
    });

    test('les initiales blanches tiennent sur chaque fond d\'avatar', () {
      // La palette est privée : on teste les couleurs qu'elle référence.
      const fonds = <String, Color>{
        'primary': DonyColors.primary,
        'terra700': DonyColors.terra700,
        'ink900': DonyColors.ink900,
        'info': DonyColors.info,
        'purple': DonyColors.purple,
        'teal': DonyColors.teal,
      };
      fonds.forEach((nom, fond) {
        expectContrast(DonyColors.neutral0, fond, 4.5, 'initiales sur $nom');
      });
    });

    test('les aplats de haut contraste tiennent 7:1', () {
      expectContrast(DonyColors.neutral0, DonyColors.primaryHc, 7,
          'libellé sur primary, HC clair');
      expectContrast(DonyColors.neutral0, DonyColors.successHc, 7,
          'libellé sur success, HC clair');
      expectContrast(DonyColors.neutral0, DonyColors.dangerHc, 7,
          'libellé sur danger, HC clair');
      expectContrast(DonyColors.neutral0, DonyColors.accentHc, 7,
          'libellé sur accent, HC clair');

      expectContrast(DonyColors.onBrandHcDark, DonyColors.primaryHcDark, 7,
          'libellé sur primary, HC sombre');
      expectContrast(DonyColors.onBrandHcDark, DonyColors.successHcDark, 7,
          'libellé sur success, HC sombre');
      expectContrast(DonyColors.onBrandHcDark, DonyColors.dangerHcDark, 7,
          'libellé sur danger, HC sombre');
      expectContrast(DonyColors.onBrandHcDark, DonyColors.accentHcDark, 7,
          'libellé sur accent, HC sombre');
    });
  });

  group('champs de saisie', () {
    // Lu depuis le thème et non depuis les tokens : c'est le thème qui décide
    // quelle couleur atterrit sur un champ, et c'est là qu'était le défaut.
    Color hintColor(ThemeData t) => t.inputDecorationTheme.hintStyle!.color!;
    Color borderColor(ThemeData t) =>
        (t.inputDecorationTheme.enabledBorder! as OutlineInputBorder)
            .borderSide
            .color;

    testWidgets('le placeholder est du texte lisible', (tester) async {
      final clair = AppTheme.light();
      expectContrast(hintColor(clair), clair.colorScheme.surface, 4.5,
          'placeholder, thème clair');

      final sombre = AppTheme.dark();
      expectContrast(hintColor(sombre), sombre.colorScheme.surface, 4.5,
          'placeholder, thème sombre');
    });

    testWidgets('le contour du champ atteint 3:1 sur son remplissage',
        (tester) async {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        expectContrast(
          borderColor(theme),
          theme.inputDecorationTheme.fillColor!,
          3,
          'contour de champ, ${theme.brightness}',
        );
      }
    });

    testWidgets('le contour du champ reste visible sur le fond d\'écran',
        (tester) async {
      // Le champ est posé sur le fond d'app, pas sur sa propre surface : un
      // contour qui ne tient que face au remplissage disparaîtrait au bord.
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        expectContrast(
          borderColor(theme),
          theme.scaffoldBackgroundColor,
          3,
          'contour de champ sur fond d\'écran, ${theme.brightness}',
        );
      }
    });

    testWidgets('le haut contraste garde sa propre bordure', (tester) async {
      for (final theme in [
        AppTheme.light(a11y: const A11yThemeOptions(highContrast: true)),
        AppTheme.dark(a11y: const A11yThemeOptions(highContrast: true)),
      ]) {
        expect(borderColor(theme), theme.colorScheme.outline);
        expectContrast(borderColor(theme), theme.colorScheme.surface, 3,
            'contour HC, ${theme.brightness}');
      }
    });
  });

  group('ColorScheme', () {
    // `testWidgets` et non `test` : construire un ThemeData déclenche le
    // chargement des polices Google, qui tente un accès réseau hors du binding
    // de test.
    testWidgets('onPrimary bascule au noir en haut contraste sombre',
        (tester) async {
      final cs = AppTheme.dark(
        a11y: const A11yThemeOptions(highContrast: true),
      ).colorScheme;
      expect(cs.onPrimary, DonyColors.onBrandHcDark);
      expectContrast(cs.onPrimary, cs.primary, 7, 'onPrimary sur primary');
    });

    testWidgets('onPrimary reste blanc partout ailleurs', (tester) async {
      for (final cs in [
        AppTheme.light().colorScheme,
        AppTheme.dark().colorScheme,
        AppTheme.light(a11y: const A11yThemeOptions(highContrast: true))
            .colorScheme,
      ]) {
        expect(cs.onPrimary, DonyColors.textOnBrand);
      }
    });
  });

  group('DonyButton en haut contraste', () {
    /// Récupère le dégradé peint par le bouton.
    LinearGradient gradientOf(WidgetTester tester) {
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      return (container.decoration! as BoxDecoration).gradient!
          as LinearGradient;
    }

    Future<void> pump(
      WidgetTester tester, {
      required bool highContrast,
      required Brightness brightness,
      DonyButtonVariant variant = DonyButtonVariant.primary,
    }) async {
      final options = A11yThemeOptions(highContrast: highContrast);
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.light(a11y: options)
              : AppTheme.dark(a11y: options),
          home: AccessibilityScope(
            underlineLinks: false,
            reinforceLabels: false,
            persistentMessages: false,
            confirmImportantActions: false,
            highContrast: highContrast,
            child: Scaffold(
              body: DonyButton(
                label: 'Confirmer',
                variant: variant,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      // MaterialApp anime les changements de thème : sans cette stabilisation,
      // la première frame après un re-pump porte encore l'ancien ColorScheme.
      await tester.pumpAndSettle();
    }

    testWidgets('garde son dégradé hors haut contraste', (tester) async {
      await pump(tester,
          highContrast: false, brightness: Brightness.light);
      final colors = gradientOf(tester).colors;
      expect(
        colors.toSet().length,
        greaterThan(1),
        reason: 'le rendu normal doit rester dégradé',
      );
    });

    testWidgets('devient un aplat mesuré en haut contraste clair',
        (tester) async {
      await pump(tester, highContrast: true, brightness: Brightness.light);
      final colors = gradientOf(tester).colors;
      expect(colors.toSet().length, 1, reason: 'aplat attendu');
      expectContrast(DonyColors.textOnBrand, colors.first, 7,
          'libellé sur aplat, HC clair');
    });

    testWidgets('devient un aplat mesuré en haut contraste sombre',
        (tester) async {
      await pump(tester, highContrast: true, brightness: Brightness.dark);
      final colors = gradientOf(tester).colors;
      expect(colors.toSet().length, 1, reason: 'aplat attendu');
      expectContrast(DonyColors.onBrandHcDark, colors.first, 7,
          'libellé sur aplat, HC sombre');
    });

    testWidgets('chaque variant pleine tient 7:1 en haut contraste',
        (tester) async {
      const variants = [
        DonyButtonVariant.primary,
        DonyButtonVariant.success,
        DonyButtonVariant.destructive,
        DonyButtonVariant.accent,
      ];
      for (final brightness in Brightness.values) {
        final fg = brightness == Brightness.dark
            ? DonyColors.onBrandHcDark
            : DonyColors.textOnBrand;
        for (final variant in variants) {
          await pump(
            tester,
            highContrast: true,
            brightness: brightness,
            variant: variant,
          );
          final colors = gradientOf(tester).colors;
          expect(colors.toSet().length, 1,
              reason: '$variant / $brightness : aplat attendu');
          expectContrast(fg, colors.first, 7, '$variant / $brightness');
        }
      }
    });

    testWidgets('le libellé passe au noir en haut contraste sombre',
        (tester) async {
      await pump(tester, highContrast: true, brightness: Brightness.dark);
      final theme = tester.widget<DefaultTextStyle>(
        find
            .descendant(
              of: find.byType(DonyButton),
              matching: find.byType(DefaultTextStyle),
            )
            .last,
      );
      expect(theme.style.color, DonyColors.onBrandHcDark);
    });
  });

  group('DonyAvatar', () {
    testWidgets('n\'utilise plus terra500 comme fond d\'initiales',
        (tester) async {
      // terra500 ne tenait que 3.46:1 avec des initiales blanches. Le test
      // balaie assez d'initiales pour couvrir les six entrées de la palette.
      const noms = [
        'Ada Lovelace',
        'Bilal Ndiaye',
        'Chloé Martin',
        'Diane Koffi',
        'Elias Traoré',
        'Fatou Sow',
        'Gustave Eiffel',
        'Hawa Diarra',
        'Ines Dubois',
        'Jules Verne',
        'Kadi Camara',
        'Louis Pasteur',
      ];
      for (final nom in noms) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: DonyAvatar(name: nom)),
          ),
        );
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(DonyAvatar),
            matching: find.byType(Container),
          ).first,
        );
        final bg = (container.decoration! as BoxDecoration).color!;
        expect(bg, isNot(DonyColors.terra500), reason: 'fond pour « $nom »');
        expectContrast(DonyColors.neutral0, bg, 4.5, 'initiales de « $nom »');
      }
    });
  });
}

/// Le ratio ne dépend pas de l'ordre des deux couleurs.
void expectSymmetry() {
  const a = Color(0xFF0B5FFF);
  const b = Color(0xFFFFFFFF);
  expect(contrastRatio(a, b), closeTo(contrastRatio(b, a), 1e-9));
}
