import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/data/models/user_preferences_model.dart';
import 'package:dony/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_analytics_backend.dart';

class MockAppPreferencesBloc
    extends MockBloc<AppPreferencesEvent, AppPreferencesState>
    implements AppPreferencesBloc {}

class _FakeAppPreferencesEvent extends Fake implements AppPreferencesEvent {}

class MockAnalyticsService extends Mock implements AnalyticsService {}

Widget _wrap({UserPreferencesModel? prefs}) {
  final mockBloc = MockAppPreferencesBloc();
  final state = AppPreferencesState(
    preferences: prefs ?? const UserPreferencesModel(),
  );
  when(() => mockBloc.state).thenReturn(state);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider<AppPreferencesBloc>.value(
          value: mockBloc,
          child: const SettingsScreen(),
        ),
      ),
      // Stub routes used by SettingsScreen navigation items
      GoRoute(path: '/settings/security', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/settings/privacy', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/settings/data', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, _) => const Scaffold(),
      ),
      GoRoute(
        path: '/settings/preferences',
        builder: (_, _) => const Scaffold(),
      ),
      GoRoute(
        path: '/settings/accessibility',
        builder: (_, _) => const Scaffold(),
      ),
      GoRoute(
        path: '/settings/legal/terms',
        builder: (_, _) => const Scaffold(),
      ),
      GoRoute(
        path: '/settings/legal/privacy',
        builder: (_, _) => const Scaffold(),
      ),
      GoRoute(
        path: '/settings/diagnostics',
        builder: (_, _) => const Scaffold(),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

void main() {
  late MockHiveService mockHive;
  late MockBox mockBox;
  late MockAnalyticsService mockAnalytics;

  setUpAll(() {
    registerFallbackValue(_FakeAppPreferencesEvent());
    mockHive = MockHiveService();
    mockBox = MockBox();
    when(() => mockHive.userPrefs).thenReturn(mockBox);
    when(() => mockBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockBox.keys).thenReturn(<dynamic>[
      '${HiveService.kContextualTutorialDismissedPrefix}search_basics',
      '${HiveService.kContextualTutorialDismissedPrefix}publish_flow',
      HiveService.kThemeMode,
    ]);
    when(() => mockBox.delete(any())).thenAnswer((_) async {});
    getIt.registerSingleton<HiveService>(mockHive);
    mockAnalytics = MockAnalyticsService();
    when(
      () => mockAnalytics.logEvent(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    getIt.registerSingleton<AnalyticsService>(mockAnalytics);
  });

  tearDownAll(() => getIt.reset());

  group('SettingsScreen', () {
    testWidgets('renders Paramètres title', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Paramètres'), findsOneWidget);
    });

    testWidgets('APPARENCE : ligne Thème sans segmented', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('APPARENCE'), findsOneWidget);
      expect(find.text('Thème'), findsOneWidget);
      expect(find.byType(SegmentedButton<String>), findsNothing);
    });

    testWidgets('shows LANGUE & COMMUNICATION section', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('LANGUE & COMMUNICATION'), findsOneWidget);
      expect(find.text('Langue'), findsOneWidget);
    });

    testWidgets(
      'DESTINATIONS FAVORITES : ligne disclosure (pas de chips inline)',
      (tester) async {
        await tester.pumpWidget(_wrap());
        await tester.pumpAndSettle();

        expect(find.text('DESTINATIONS FAVORITES'), findsOneWidget);
        expect(find.text('Destinations'), findsOneWidget);
        // villes absentes de la liste principale (uniquement dans le picker)
        expect(find.textContaining('Abidjan'), findsNothing);
      },
    );

    testWidgets('ligne Destinations résume la sélection', (tester) async {
      await tester.pumpWidget(
        _wrap(prefs: const UserPreferencesModel(favDestinations: ['SN'])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dakar'), findsOneWidget);
    });

    testWidgets('shows SÉCURITÉ & DONNÉES section', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('SÉCURITÉ & DONNÉES'), findsOneWidget);
      expect(find.text('Sécurité'), findsOneWidget);
      expect(find.text('Confidentialité'), findsOneWidget);
      expect(find.text('Mes données'), findsOneWidget);
    });

    testWidgets('shows PERSONNALISATION section', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Use skipOffstage: false to find widgets that are scrolled out of view
      expect(
        find.text('PERSONNALISATION', skipOffstage: false),
        findsOneWidget,
      );
      expect(find.text('Notifications', skipOffstage: false), findsOneWidget);
      expect(find.text('Préférences', skipOffstage: false), findsOneWidget);
      expect(find.text('Accessibilité', skipOffstage: false), findsOneWidget);
      expect(
        find.text('Réafficher les suggestions', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('tap Réafficher les suggestions efface les flags Hive et logue '
        "l'event", (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Réafficher les suggestions'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Réafficher les suggestions'));
      await tester.pump();

      for (final id in const ['trip', 'parcel', 'alert', 'kyc', 'tutorial']) {
        verify(
          () => mockBox.put(
            '${HiveService.kGuidanceSlideDismissedPrefix}$id',
            false,
          ),
        ).called(1);
      }
      // Toutes les ContextualTutorialCard fermées ailleurs dans l'app
      // (une clé par tutoriel) doivent aussi être effacées, sans toucher
      // aux autres préférences stockées dans la même box.
      verify(
        () => mockBox.delete(
          '${HiveService.kContextualTutorialDismissedPrefix}search_basics',
        ),
      ).called(1);
      verify(
        () => mockBox.delete(
          '${HiveService.kContextualTutorialDismissedPrefix}publish_flow',
        ),
      ).called(1);
      verifyNever(() => mockBox.delete(HiveService.kThemeMode));
      verify(
        () =>
            mockAnalytics.logEvent(AnalyticsEvents.settingsGuidanceCardsReset),
      ).called(1);

      await tester.pumpAndSettle();
      expect(find.text('Suggestions et tutoriels réaffichés.'), findsOneWidget);
    });

    testWidgets('shows INFORMATIONS section', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Scroll to bottom to reveal the INFORMATIONS section
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(find.text('INFORMATIONS'), findsOneWidget);
      expect(find.text('CGU'), findsOneWidget);
      expect(find.text('Politique de confidentialité'), findsOneWidget);
      expect(find.text('Diagnostics'), findsOneWidget);
    });

    testWidgets('ligne Thème affiche Sombre quand themeMode dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(prefs: const UserPreferencesModel(themeMode: 'dark')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sombre'), findsOneWidget);
    });

    testWidgets('ligne Thème affiche Auto quand themeMode system', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(prefs: const UserPreferencesModel()));
      await tester.pumpAndSettle();
      expect(find.text('Auto'), findsOneWidget);
    });

    testWidgets('language shows Français when languageCode is fr', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(prefs: const UserPreferencesModel()));
      await tester.pumpAndSettle();

      expect(find.text('Français'), findsOneWidget);
    });

    testWidgets('language shows English when languageCode is en', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(prefs: const UserPreferencesModel(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      expect(find.text('English'), findsOneWidget);
    });

    testWidgets(
      'tap ligne Thème → picker → Sombre dispatch ThemeChanged(dark)',
      (tester) async {
        final mockBloc = MockAppPreferencesBloc();
        const state = AppPreferencesState(preferences: UserPreferencesModel());
        when(() => mockBloc.state).thenReturn(state);
        whenListen<AppPreferencesState>(
          mockBloc,
          const Stream.empty(),
          initialState: state,
        );

        await tester.pumpWidget(_wrapWithBloc(mockBloc));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thème'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sombre').last);
        await tester.pump();

        verify(() => mockBloc.add(const ThemeChanged('dark'))).called(1);
      },
    );

    testWidgets(
      'tap ligne Thème → picker → Clair dispatch ThemeChanged(light)',
      (tester) async {
        final mockBloc = MockAppPreferencesBloc();
        const state = AppPreferencesState(
          preferences: UserPreferencesModel(themeMode: 'dark'),
        );
        when(() => mockBloc.state).thenReturn(state);
        whenListen<AppPreferencesState>(
          mockBloc,
          const Stream.empty(),
          initialState: state,
        );

        await tester.pumpWidget(_wrapWithBloc(mockBloc));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thème'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Clair').last);
        await tester.pump();

        verify(() => mockBloc.add(const ThemeChanged('light'))).called(1);
      },
    );

    testWidgets('tap langue tile ouvre le language picker modal', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Langue'));
      await tester.pumpAndSettle();

      expect(find.text('Français'), findsAtLeastNWidgets(1));
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets(
      'tap ligne Destinations → picker → Dakar dispatch DestinationToggled',
      (tester) async {
        final mockBloc = MockAppPreferencesBloc();
        const state = AppPreferencesState(preferences: UserPreferencesModel());
        when(() => mockBloc.state).thenReturn(state);
        whenListen<AppPreferencesState>(
          mockBloc,
          const Stream.empty(),
          initialState: state,
        );

        await tester.pumpWidget(_wrapWithBloc(mockBloc));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Destinations'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Dakar'));
        await tester.pump();

        verify(
          () => mockBloc.add(any(that: isA<DestinationToggled>())),
        ).called(1);
      },
    );

    testWidgets('tap Sécurité tile navigates to /settings/security', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Sécurité'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sécurité'));
      await tester.pumpAndSettle();

      // After navigation, the security screen placeholder is shown
      expect(find.text('Sécurité'), findsNothing);
    });

    testWidgets('tap Confidentialité tile navigates to /settings/privacy', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Confidentialité'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confidentialité'));
      await tester.pumpAndSettle();

      expect(find.text('Confidentialité'), findsNothing);
    });

    testWidgets('tap Mes données tile navigates to /settings/data', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Mes données'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mes données'));
      await tester.pumpAndSettle();

      expect(find.text('Mes données'), findsNothing);
    });

    testWidgets('tap Notifications tile navigates to /settings/notifications', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Notifications'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsNothing);
    });

    testWidgets('tap Préférences tile navigates to /settings/preferences', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Préférences'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Préférences'));
      await tester.pumpAndSettle();

      expect(find.text('Préférences'), findsNothing);
    });

    testWidgets('tap Accessibilité tile navigates to /settings/accessibility', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Accessibilité'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accessibilité'));
      await tester.pumpAndSettle();

      expect(find.text('Accessibilité'), findsNothing);
    });

    testWidgets('tap CGU tile navigates to /settings/legal/terms', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Scroll to bottom to reveal INFORMATIONS section
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CGU'));
      await tester.pumpAndSettle();

      expect(find.text('CGU'), findsNothing);
    });

    testWidgets(
      'tap Politique de confidentialité tile navigates to /settings/legal/privacy',
      (tester) async {
        await tester.pumpWidget(_wrap());
        await tester.pumpAndSettle();

        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Politique de confidentialité'));
        await tester.pumpAndSettle();

        expect(find.text('Politique de confidentialité'), findsNothing);
      },
    );

    testWidgets('tap Diagnostics tile navigates to /settings/diagnostics', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Diagnostics'),
        find.byType(ListView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Diagnostics'));
      await tester.pumpAndSettle();

      expect(find.text('Diagnostics'), findsNothing);
    });

    testWidgets(
      'language picker — tap Français dispatches LanguageChanged(fr)',
      (tester) async {
        final mockBloc = MockAppPreferencesBloc();
        const state = AppPreferencesState(
          preferences: UserPreferencesModel(languageCode: 'en'),
        );
        when(() => mockBloc.state).thenReturn(state);
        whenListen<AppPreferencesState>(
          mockBloc,
          const Stream.empty(),
          initialState: state,
        );

        await tester.pumpWidget(_wrapWithBloc(mockBloc));
        await tester.pumpAndSettle();

        // Open language picker
        await tester.tap(find.text('Langue'));
        await tester.pumpAndSettle();

        // Tap Français
        await tester.tap(find.text('Français').last);
        await tester.pump();

        verify(() => mockBloc.add(any(that: isA<LanguageChanged>()))).called(1);
      },
    );

    testWidgets(
      'language picker — tap English dispatches LanguageChanged(en)',
      (tester) async {
        final mockBloc = MockAppPreferencesBloc();
        const state = AppPreferencesState(preferences: UserPreferencesModel());
        when(() => mockBloc.state).thenReturn(state);
        whenListen<AppPreferencesState>(
          mockBloc,
          const Stream.empty(),
          initialState: state,
        );

        await tester.pumpWidget(_wrapWithBloc(mockBloc));
        await tester.pumpAndSettle();

        // Open language picker
        await tester.tap(find.text('Langue'));
        await tester.pumpAndSettle();

        // Tap English
        await tester.tap(find.text('English'));
        await tester.pump();

        verify(() => mockBloc.add(any(that: isA<LanguageChanged>()))).called(1);
      },
    );
  });
}

Widget _wrapWithBloc(MockAppPreferencesBloc mockBloc) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BlocProvider<AppPreferencesBloc>.value(
          value: mockBloc,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(path: '/settings/security', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/settings/privacy', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/settings/data', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, _) => const Scaffold(),
      ),
      GoRoute(
        path: '/settings/preferences',
        builder: (_, _) => const Scaffold(),
      ),
      GoRoute(
        path: '/settings/accessibility',
        builder: (_, _) => const Scaffold(),
      ),
      GoRoute(
        path: '/settings/legal/terms',
        builder: (_, _) => const Scaffold(),
      ),
      GoRoute(
        path: '/settings/legal/privacy',
        builder: (_, _) => const Scaffold(),
      ),
      GoRoute(
        path: '/settings/diagnostics',
        builder: (_, _) => const Scaffold(),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}
