import 'dart:async';

import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:dony/core/design/widgets/dony_success_screen.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

// ── Test doubles ─────────────────────────────────────────────────────────────

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  Widget host({
    required VoidCallback onCta,
    VoidCallback? onClose,
    String? analyticsContext,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) => MaterialApp(
    theme: AppTheme.light(),
    home: DonySuccessScreen(
      mascotteType: DonyMascotteType.securise,
      title: 'Envoi réservé !',
      subtitle: 'Ton paiement est sécurisé.',
      ctaLabel: 'Voir mes envois',
      onCta: onCta,
      onClose: onClose,
      analyticsContext: analyticsContext,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
    ),
  );

  /// Harness GoRouter — nécessaire pour tester la navigation par défaut vers
  /// `/home` (le widget appelle `GoRouter.of(context)` quand `onClose` est null).
  Widget hostWithRouter({required VoidCallback onCta}) {
    final router = GoRouter(
      initialLocation: '/success',
      routes: [
        GoRoute(
          path: '/success',
          builder: (context, state) => DonySuccessScreen(
            mascotteType: DonyMascotteType.securise,
            title: 'Envoi réservé !',
            subtitle: 'Ton paiement est sécurisé.',
            ctaLabel: 'Voir mes envois',
            onCta: onCta,
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Home stub')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router, theme: AppTheme.light());
  }

  setUp(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  tearDown(() {
    if (getIt.isRegistered<AnalyticsService>()) {
      getIt.unregister<AnalyticsService>();
    }
  });

  testWidgets('affiche titre, sous-titre et label du CTA', (tester) async {
    await tester.pumpWidget(host(onCta: () {}));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Envoi réservé !'), findsOneWidget);
    expect(find.text('Ton paiement est sécurisé.'), findsOneWidget);
    expect(find.text('Voir mes envois'), findsOneWidget);
  });

  testWidgets('tap sur le CTA appelle onCta exactement une fois', (
    tester,
  ) async {
    var callCount = 0;
    await tester.pumpWidget(host(onCta: () => callCount++));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byType(DonyButton));
    await tester.pump();

    expect(callCount, 1);
  });

  testWidgets(
    'pas d\'auto-navigation : le CTA reste visible après 5 secondes',
    (tester) async {
      await tester.pumpWidget(host(onCta: () {}));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 5));

      expect(find.text('Voir mes envois'), findsOneWidget);
    },
  );

  testWidgets('affiche le bouton fermer (x)', (tester) async {
    await tester.pumpWidget(host(onCta: () {}));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byTooltip('Fermer'), findsOneWidget);
  });

  testWidgets(
    'tap sur le bouton fermer appelle onClose exactement une fois quand fourni',
    (tester) async {
      var callCount = 0;
      await tester.pumpWidget(host(onCta: () {}, onClose: () => callCount++));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pump();

      expect(callCount, 1);
    },
  );

  testWidgets('sans onClose, tap sur fermer navigue vers /home', (
    tester,
  ) async {
    await tester.pumpWidget(hostWithRouter(onCta: () {}));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    expect(find.text('Home stub'), findsOneWidget);
  });

  testWidgets('un retour arrière système (back gesture/bouton) est ignoré : '
      'l\'écran de succès reste affiché', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Formulaire sous-jacent')),
      ),
    );
    await tester.pump();

    unawaited(
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (context) => DonySuccessScreen(
            mascotteType: DonyMascotteType.securise,
            title: 'Envoi réservé !',
            subtitle: 'Ton paiement est sécurisé.',
            ctaLabel: 'Voir mes envois',
            onCta: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Envoi réservé !'), findsOneWidget);

    // Simule un retour arrière système (geste iOS / bouton Android).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Envoi réservé !'), findsOneWidget);
    expect(find.text('Formulaire sous-jacent'), findsNothing);
  });

  // ── Analytics ─────────────────────────────────────────────────────────────

  group('analytics', () {
    late _MockAnalyticsService analytics;

    setUp(() {
      analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerLazySingleton<AnalyticsService>(() => analytics);
    });

    testWidgets('analyticsContext fourni : viewed part au montage', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(onCta: () {}, analyticsContext: 'trip_published'),
      );
      await tester.pump(const Duration(milliseconds: 500));

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.successScreenViewed,
          properties: {'context': 'trip_published'},
        ),
      ).called(1);
    });

    testWidgets('analyticsContext fourni : cta_tapped part au tap CTA', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(onCta: () {}, analyticsContext: 'trip_published'),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byType(DonyButton));
      await tester.pump();

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.successScreenCtaTapped,
          properties: {'context': 'trip_published'},
        ),
      ).called(1);
    });

    testWidgets('analyticsContext fourni : closed part au tap fermer', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(onCta: () {}, onClose: () {}, analyticsContext: 'trip_published'),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pump();

      verify(
        () => analytics.logEvent(
          AnalyticsEvents.successScreenClosed,
          properties: {'context': 'trip_published'},
        ),
      ).called(1);
    });

    testWidgets('sans analyticsContext : aucun event envoyé', (tester) async {
      await tester.pumpWidget(host(onCta: () {}));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byType(DonyButton));
      await tester.pump();

      verifyNever(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      );
    });
  });

  testWidgets('sans AnalyticsService enregistré dans getIt, aucune exception '
      '(analytics best-effort)', (tester) async {
    // Pas d'enregistrement getIt ici — setUp() de haut niveau garantit
    // qu'AnalyticsService n'est pas déjà présent.
    await tester.pumpWidget(
      host(onCta: () {}, analyticsContext: 'trip_published'),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byType(DonyButton));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  // ── Confetti ─────────────────────────────────────────────────────────────

  group('confetti', () {
    testWidgets('joue un burst de confettis au montage sans exception', (
      tester,
    ) async {
      await tester.pumpWidget(host(onCta: () {}));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('dony-success-confetti')),
        findsOneWidget,
      );

      // La durée du burst (~1.8s) doit s'écouler sans lever d'exception.
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion : le painter de confettis est absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: host(onCta: () {}),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const ValueKey('dony-success-confetti')), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  });

  // ── Action secondaire ────────────────────────────────────────────────────

  group('action secondaire', () {
    testWidgets(
      'secondaryLabel + onSecondary fournis : le bouton secondaire s\'affiche',
      (tester) async {
        await tester.pumpWidget(
          host(
            onCta: () {},
            secondaryLabel: 'Partager mon trajet',
            onSecondary: () {},
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Partager mon trajet'), findsOneWidget);
        expect(find.byType(DonyButton), findsNWidgets(2));
      },
    );

    testWidgets('sans secondaryLabel/onSecondary : aucun bouton secondaire', (
      tester,
    ) async {
      await tester.pumpWidget(host(onCta: () {}));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DonyButton), findsOneWidget);
    });

    testWidgets(
      'tap sur le bouton secondaire appelle onSecondary exactement une fois',
      (tester) async {
        var callCount = 0;
        await tester.pumpWidget(
          host(
            onCta: () {},
            secondaryLabel: 'Partager mon trajet',
            onSecondary: () => callCount++,
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.tap(find.text('Partager mon trajet'));
        await tester.pump();

        expect(callCount, 1);
      },
    );

    testWidgets(
      'analyticsContext fourni : secondary_tapped part au tap secondaire',
      (tester) async {
        final analytics = _MockAnalyticsService();
        when(
          () => analytics.logEvent(any(), properties: any(named: 'properties')),
        ).thenAnswer((_) async {});
        getIt.registerLazySingleton<AnalyticsService>(() => analytics);

        await tester.pumpWidget(
          host(
            onCta: () {},
            analyticsContext: 'trip_published',
            secondaryLabel: 'Partager mon trajet',
            onSecondary: () {},
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.tap(find.text('Partager mon trajet'));
        await tester.pump();

        verify(
          () => analytics.logEvent(
            AnalyticsEvents.successScreenSecondaryTapped,
            properties: {'context': 'trip_published'},
          ),
        ).called(1);
      },
    );
  });
}
