import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduit le câblage racine de `app.dart` sans démarrer toute
/// l'application : Firebase, Hive et le routeur ne sont pas nécessaires pour
/// vérifier la propagation.
Widget harness(AccessibilityState state, {required Widget child}) {
  final effectiveContrast = state.highContrast == AccessibilityMode.on;
  final effectiveMotion = state.reduceMotion == AccessibilityMode.on;
  return MaterialApp(
    theme: AppTheme.light(
      a11y: A11yThemeOptions(
        highContrast: effectiveContrast,
        reduceMotion: effectiveMotion,
        underlineLinks: state.underlineLinks,
      ),
    ),
    builder: (context, inner) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          textScaler: state.followSystemTextScale
              ? mq.textScaler.clamp(maxScaleFactor: kA11yMaxTextScale)
              : TextScaler.linear(state.textScaleFactor),
          boldText: state.boldText,
          disableAnimations: effectiveMotion,
        ),
        child: AccessibilityScope(
          underlineLinks: state.underlineLinks,
          reinforceLabels: state.reinforceLabels,
          persistentMessages: state.persistentMessages,
          confirmImportantActions: state.confirmImportantActions,
          child: inner ?? const SizedBox.shrink(),
        ),
      );
    },
    home: child,
  );
}

void main() {
  group('Propagation des réglages depuis la racine', () {
    testWidgets('un facteur manuel atteint MediaQuery.textScalerOf',
        (tester) async {
      late double scaled;
      await tester.pumpWidget(harness(
        const AccessibilityState(
          followSystemTextScale: false,
          textScaleFactor: 1.5,
        ),
        child: Builder(builder: (ctx) {
          scaled = MediaQuery.textScalerOf(ctx).scale(10);
          return const SizedBox.shrink();
        }),
      ));
      expect(scaled, 15.0);
    });

    testWidgets('le suivi système est plafonné à 200 %', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      late double scaled;
      await tester.pumpWidget(harness(
        const AccessibilityState(followSystemTextScale: true),
        child: Builder(builder: (ctx) {
          scaled = MediaQuery.textScalerOf(ctx).scale(10);
          return const SizedBox.shrink();
        }),
      ));
      expect(scaled, 20.0);
    });

    testWidgets('le gras atteint MediaQuery.boldTextOf', (tester) async {
      late bool bold;
      await tester.pumpWidget(harness(
        const AccessibilityState(boldText: true),
        child: Builder(builder: (ctx) {
          bold = MediaQuery.boldTextOf(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(bold, isTrue);
    });

    testWidgets('la réduction du mouvement atteint disableAnimations',
        (tester) async {
      late bool disabled;
      await tester.pumpWidget(harness(
        const AccessibilityState(reduceMotion: AccessibilityMode.on),
        child: Builder(builder: (ctx) {
          disabled = MediaQuery.disableAnimationsOf(ctx);
          return const SizedBox.shrink();
        }),
      ));
      expect(disabled, isTrue);
    });

    testWidgets('le contraste forcé sélectionne la variante contrastée',
        (tester) async {
      late Color onSurface;
      await tester.pumpWidget(harness(
        const AccessibilityState(highContrast: AccessibilityMode.on),
        child: Builder(builder: (ctx) {
          onSurface = Theme.of(ctx).colorScheme.onSurface;
          return const SizedBox.shrink();
        }),
      ));
      expect(onSurface, DonyColors.textPrimaryHc);
    });

    testWidgets('les flags du scope sont lisibles via context.a11y',
        (tester) async {
      late bool reinforce;
      await tester.pumpWidget(harness(
        const AccessibilityState(reinforceLabels: true),
        child: Builder(builder: (ctx) {
          reinforce = ctx.a11y.reinforceLabels;
          return const SizedBox.shrink();
        }),
      ));
      expect(reinforce, isTrue);
    });
  });
}
