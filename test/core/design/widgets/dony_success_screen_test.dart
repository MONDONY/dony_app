import 'dart:async';

import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/design/widgets/dony_mascotte.dart';
import 'package:dony/core/design/widgets/dony_success_screen.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/assistant/presentation/assistant_bubble_blockers.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/data/models/video_modal_moment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../features/video_modal/moment_test_support.dart';
import '../../../helpers/l10n_test_helpers.dart';

// ── Test doubles ─────────────────────────────────────────────────────────────

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  Widget host({
    required VoidCallback onCta,
    VoidCallback? onClose,
    String? analyticsContext,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    String? tertiaryLabel,
    VoidCallback? onTertiary,
    List<DonySuccessAction> extraActions = const [],
    String? secondaryIconAsset = 'share-2',
    VideoModalMoment? modalMoment,
  }) => MaterialApp(
    theme: AppTheme.light(),
    home: DonySuccessScreen(
      mascotteType: DonyMascotteType.securise,
      title: 'Envoi réservé !',
      subtitle: 'Votre paiement est sécurisé.',
      ctaLabel: 'Voir mes envois',
      onCta: onCta,
      onClose: onClose,
      analyticsContext: analyticsContext,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
      tertiaryLabel: tertiaryLabel,
      onTertiary: onTertiary,
      extraActions: extraActions,
      secondaryIconAsset: secondaryIconAsset,
      modalMoment: modalMoment,
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
            subtitle: 'Votre paiement est sécurisé.',
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

  group('moment d\'action des modals', () {
    testWidgets('émis à l\'affichage, avec l\'écran comme origine', (
      tester,
    ) async {
      final moments = useRecordingMoments();
      final moment = VideoModalMoment.action(
        VideoModalTrigger.paymentSucceeded,
      );
      await tester.pumpWidget(host(onCta: () {}, modalMoment: moment));
      await tester.pump(const Duration(milliseconds: 500));

      expect(moments.emitted, [moment]);
      expect(moments.origins.single, isNotNull);
      expect(moments.origins.single!.mounted, isTrue);
      // L'écran n'est pas perturbé.
      expect(find.text('Envoi réservé !'), findsOneWidget);
      expect(find.text('Voir mes envois'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('émis une seule fois malgré les reconstructions', (
      tester,
    ) async {
      final moments = useRecordingMoments();
      final moment = VideoModalMoment.action(VideoModalTrigger.tripPublished);
      await tester.pumpWidget(host(onCta: () {}, modalMoment: moment));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(host(onCta: () {}, modalMoment: moment));
      await tester.pump(const Duration(milliseconds: 500));
      expect(moments.emitted, hasLength(1));
    });

    testWidgets('sans moment : rien n\'est émis', (tester) async {
      final moments = useRecordingMoments();
      await tester.pumpWidget(host(onCta: () {}));
      await tester.pump(const Duration(milliseconds: 500));
      expect(moments.emitted, isEmpty);
    });
  });

  // Redmi 720x1640 : barre de navigation à 3 boutons de 48 dp (96 px) ; petit
  // écran 360x640. Les boutons sont dans une zone fixe, au-dessus de la barre,
  // quelle que soit la façon dont l'inset arrive (padding, viewPadding, ou
  // viewPadding seul quand le Scaffold/bord à bord a consommé le padding).
  final configs =
      <
        ({
          String name,
          Size size,
          double ratio,
          double padding,
          double viewPadding,
        })
      >[
        (
          name: 'padding 0 / viewPadding 48 (Redmi)',
          size: const Size(720, 1640),
          ratio: 2,
          padding: 0,
          viewPadding: 48,
        ),
        (
          name: 'padding 48 / viewPadding 48 (Redmi)',
          size: const Size(720, 1640),
          ratio: 2,
          padding: 48,
          viewPadding: 48,
        ),
        (
          name: 'sans barre (720x1640)',
          size: const Size(720, 1640),
          ratio: 2,
          padding: 0,
          viewPadding: 0,
        ),
        (
          name: 'petit écran 360x640 avec barre',
          size: const Size(360, 640),
          ratio: 1,
          padding: 0,
          viewPadding: 48,
        ),
      ];
  for (final c in configs) {
    testWidgets('boutons visibles au-dessus de la barre système : ${c.name}', (
      tester,
    ) async {
      tester.view
        ..physicalSize = c.size
        ..devicePixelRatio = c.ratio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.only(bottom: c.padding),
              viewPadding: EdgeInsets.only(bottom: c.viewPadding),
            ),
            child: child!,
          ),
          home: DonySuccessScreen(
            mascotteType: DonyMascotteType.securise,
            title: 'Trajet publié !',
            subtitle: 'Votre trajet est en ligne.',
            ctaLabel: 'Voir les colis',
            onCta: () {},
            secondaryLabel: 'Voir mon trajet',
            onSecondary: () {},
            tertiaryLabel: 'Partager',
            onTertiary: () {},
            extraActions: [DonySuccessAction(label: 'Autre', onTap: () {})],
            secondaryIconAsset: null,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);

      final viewportBottom = c.size.height / c.ratio;
      final principal = find.widgetWithText(DonyButton, 'Voir les colis');
      final secondaire = find.widgetWithText(DonyButton, 'Voir mon trajet');
      final dernier = find.widgetWithText(DonyButton, 'Autre');

      // Sans aucun défilement : tous les boutons sont à l'écran et au-dessus
      // de la barre (bord bas moins l'inset).
      for (final f in [principal, secondaire, dernier]) {
        expect(
          tester.getBottomLeft(f).dy,
          lessThanOrEqualTo(viewportBottom - c.viewPadding),
        );
        expect(tester.getTopLeft(f).dy, greaterThanOrEqualTo(0));
      }
      expect(
        viewportBottom - tester.getBottomLeft(dernier).dy,
        greaterThanOrEqualTo(c.viewPadding + DonySpacing.lg),
      );
      expect(
        tester.getBottomLeft(principal).dy,
        lessThan(tester.getTopLeft(secondaire).dy),
      );
      // Le bouton secondaire reçoit bien le tap à son centre.
      await tester.tap(secondaire);
      await tester.pump();
    });
  }

  // Recette du 14/11 : la bulle de l'assistant, au milieu du bord droit,
  // masquait le sous-titre de « Offer sent! ». Masquée sur l'écran de succès,
  // rendue à sa fermeture.
  testWidgets('la bulle de l\'assistant est masquée tant que l\'écran est '
      'affiché', (tester) async {
    assistantBubbleBlockers.reset();
    addTearDown(assistantBubbleBlockers.reset);
    await tester.pumpWidget(host(onCta: () {}));
    await tester.pump(const Duration(milliseconds: 500));
    expect(assistantBubbleBlockers.active.value, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(assistantBubbleBlockers.active.value, isFalse);
  });

  testWidgets('affiche titre, sous-titre et label du CTA', (tester) async {
    await tester.pumpWidget(host(onCta: () {}));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Envoi réservé !'), findsOneWidget);
    expect(find.text('Votre paiement est sécurisé.'), findsOneWidget);
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

  testWidgets('bouton fermer traduit en anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(host(onCta: () {}));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byTooltip('Fermer'), findsNothing);
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

  testWidgets('sans onClose, écran poussé hors GoRouter depuis /home : '
      'la croix le ferme (FLUTTER-P5)', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DonySuccessScreen(
                      mascotteType: DonyMascotteType.succes,
                      title: 'Offre envoyée !',
                      subtitle: 'Le voyageur va répondre.',
                      ctaLabel: 'Voir mon envoi',
                      onCta: () {},
                    ),
                  ),
                ),
                child: const Text('Home stub'),
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );
    await tester.tap(find.text('Home stub'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Offre envoyée !'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Offre envoyée !'), findsNothing);
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
            subtitle: 'Votre paiement est sécurisé.',
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

  // ── Action tertiaire (ex. « Configurer mes paiements ») ─────────────────

  group('action tertiaire', () {
    tearDown(getIt.reset);

    testWidgets('fournie : bouton affiché sous le secondaire, callback appelé '
        'et tap tracé', (tester) async {
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerLazySingleton<AnalyticsService>(() => analytics);
      var tapped = 0;

      await tester.pumpWidget(
        host(
          onCta: () {},
          analyticsContext: 'trip_published',
          secondaryLabel: 'Partager mon trajet',
          onSecondary: () {},
          tertiaryLabel: 'Configurer mes paiements',
          onTertiary: () => tapped++,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(DonyButton), findsNWidgets(3));
      // Trois boutons : le tertiaire passe sous la surface de test (800×600),
      // l'écran défile comme sur un petit téléphone.
      await tester.ensureVisible(
        find.byKey(const Key('success-screen-tertiary')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('success-screen-tertiary')));
      await tester.pump();

      expect(tapped, 1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.successScreenTertiaryTapped,
          properties: {'context': 'trip_published'},
        ),
      ).called(1);
    });

    testWidgets('absente : aucun bouton tertiaire', (tester) async {
      await tester.pumpWidget(host(onCta: () {}));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('success-screen-tertiary')), findsNothing);
    });
  });

  group('actions supplémentaires', () {
    tearDown(getIt.reset);

    testWidgets('affichées dans l\'ordre sous le tertiaire, chaque tap appelle '
        'son callback et trace sa position', (tester) async {
      final analytics = _MockAnalyticsService();
      when(
        () => analytics.logEvent(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      getIt.registerLazySingleton<AnalyticsService>(() => analytics);
      final taps = <String>[];

      await tester.pumpWidget(
        host(
          onCta: () {},
          analyticsContext: 'trip_published_v2',
          tertiaryLabel: 'Partager mon affiche',
          onTertiary: () => taps.add('tertiaire'),
          extraActions: [
            DonySuccessAction(
              label: 'Configurer mes paiements',
              onTap: () => taps.add('premiere'),
            ),
            DonySuccessAction(
              label: 'Autre lien',
              onTap: () => taps.add('seconde'),
            ),
          ],
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Configurer mes paiements'), findsOneWidget);
      expect(find.text('Autre lien'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('success-screen-extra-1')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('success-screen-extra-0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('success-screen-extra-1')));
      await tester.pump();

      expect(taps, ['premiere', 'seconde']);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.successScreenTertiaryTapped,
          properties: {'context': 'trip_published_v2', 'position': 2},
        ),
      ).called(1);
      verify(
        () => analytics.logEvent(
          AnalyticsEvents.successScreenTertiaryTapped,
          properties: {'context': 'trip_published_v2', 'position': 3},
        ),
      ).called(1);
    });

    testWidgets('par défaut : aucune action supplémentaire', (tester) async {
      await tester.pumpWidget(host(onCta: () {}));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('success-screen-extra-0')), findsNothing);
    });
  });

  group('icône du bouton secondaire', () {
    testWidgets('par défaut : icône de partage', (tester) async {
      await tester.pumpWidget(
        host(
          onCta: () {},
          secondaryLabel: 'Partager mon trajet',
          onSecondary: () {},
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final secondary = tester.widget<DonyButton>(
        find.widgetWithText(DonyButton, 'Partager mon trajet'),
      );
      expect(secondary.iconAsset, 'share-2');
    });

    testWidgets('null : bouton secondaire sans icône', (tester) async {
      await tester.pumpWidget(
        host(
          onCta: () {},
          secondaryLabel: 'Voir mon trajet',
          onSecondary: () {},
          secondaryIconAsset: null,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final secondary = tester.widget<DonyButton>(
        find.widgetWithText(DonyButton, 'Voir mon trajet'),
      );
      expect(secondary.iconAsset, isNull);
    });
  });
}
