import 'package:dony/app/reduced_motion_priming.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

class _MockBox extends Mock implements Box<dynamic> {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

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

  group('primeReducedMotionDuration — synchronisation à froid (rondes 1 et 2)',
      () {
    late _MockBox box;
    late _MockAnalyticsService analytics;

    setUp(() {
      box = _MockBox();
      analytics = _MockAnalyticsService();
      when(() => box.get(any(), defaultValue: any(named: 'defaultValue')))
          .thenAnswer((inv) => inv.namedArguments[#defaultValue]);
      when(() => box.get(any())).thenReturn(null);
      when(() => box.put(any(), any())).thenAnswer((_) async {});
      when(() => box.delete(any())).thenAnswer((_) async {});
      when(() => analytics.logEvent(any(),
          properties: any(named: 'properties'))).thenAnswer((_) async {});
    });

    test(
        // Ronde 1.
        'un bloc dont l\'état initial (chargé depuis Hive, sans emit) porte '
        'reduceMotion: on force Animate.defaultDuration à zéro, sans '
        'qu\'aucun événement n\'ait été ajouté au bloc, même si le système '
        'ne demande pas de réduction', () {
      when(() => box.get(HiveService.kA11yReduceMotion,
              defaultValue: any(named: 'defaultValue')))
          .thenReturn(AccessibilityMode.on);

      // L'état initial vient de `super(_load(_box))`, jamais d'un
      // `emit()` : reproduit exactement ce que lit `didChangeDependencies`
      // via `getIt<AccessibilityBloc>().state` avant le premier `build`,
      // sans qu'aucun événement ne soit ajouté au bloc.
      final bloc = AccessibilityBloc(box, analytics);
      addTearDown(bloc.close);
      expect(bloc.state.reduceMotion, AccessibilityMode.on);

      primeReducedMotionDuration(bloc.state, systemReducesMotion: false);

      expect(Animate.defaultDuration, Duration.zero);
      verifyNever(() => analytics.logEvent(any(),
          properties: any(named: 'properties')));
    });

    test(
        // Ronde 2 — 'system' est la valeur par défaut de reduceMotion,
        // donc le chemin le plus fréquent, pas un cas limite : l'utilisateur
        // qui a activé la réduction dans les réglages de son téléphone sans
        // jamais ouvrir l'écran d'accessibilité dony.
        'un état reduceMotion: system avec un système qui demande la '
        'réduction force Animate.defaultDuration à zéro', () {
      primeReducedMotionDuration(
        const AccessibilityState(reduceMotion: AccessibilityMode.system),
        systemReducesMotion: true,
      );
      expect(Animate.defaultDuration, Duration.zero);
    });

    test(
        'un état reduceMotion: system avec un système qui ne demande pas la '
        'réduction laisse Animate.defaultDuration à sa valeur normale', () {
      primeReducedMotionDuration(
        const AccessibilityState(reduceMotion: AccessibilityMode.system),
        systemReducesMotion: false,
      );
      expect(Animate.defaultDuration, const Duration(milliseconds: 300));
    });

    test(
        'un état reduceMotion: off avec un système qui demande la réduction '
        'garde Animate.defaultDuration à sa valeur normale : le choix '
        'explicite de l\'utilisateur prime sur le système', () {
      primeReducedMotionDuration(
        const AccessibilityState(reduceMotion: AccessibilityMode.off),
        systemReducesMotion: true,
      );
      expect(Animate.defaultDuration, const Duration(milliseconds: 300));
    });
  });
}
