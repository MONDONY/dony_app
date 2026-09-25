import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/storage/hive_service.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/data/models/user_preferences_model.dart';
import 'package:dony/features/settings/presentation/settings_screen.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/l10n_test_helpers.dart';
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
      GoRoute(path: '/legal/terms', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/legal/privacy', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/settings/diagnostics',
        builder: (_, _) => const Scaffold(),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

/// Câblage réel (`AppPreferencesBloc` non moqué + locale effective) : même
/// montage que `MaterialApp.router` dans `lib/app/app.dart`, pour vérifier
/// bout en bout qu'un changement de langue dans Réglages se propage au
/// texte affiché sans reconstruire l'arbre de widgets.
Widget _wrapReal(AppPreferencesBloc bloc) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SettingsScreen()),
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
      GoRoute(path: '/legal/terms', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/legal/privacy', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/settings/diagnostics',
        builder: (_, _) => const Scaffold(),
      ),
    ],
  );

  return BlocProvider<AppPreferencesBloc>.value(
    value: bloc,
    child: BlocBuilder<AppPreferencesBloc, AppPreferencesState>(
      builder: (context, state) => MaterialApp.router(
        locale:
            state.preferences.languageCode ==
                UserPreferencesModel.kLanguageSystem
            ? null
            : Locale(state.preferences.languageCode),
        localeListResolutionCallback: AppL10n.localeListResolution,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          AppL10n.syncIntl(Localizations.localeOf(context));
          return child!;
        },
        routerConfig: router,
      ),
    ),
  );
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
      await tester.pumpWidget(
        _wrap(prefs: const UserPreferencesModel(themeMode: 'system')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Auto'), findsOneWidget);
    });

    testWidgets('langue par défaut → Langue du téléphone', (tester) async {
      await tester.pumpWidget(_wrap(prefs: const UserPreferencesModel()));
      await tester.pumpAndSettle();

      expect(find.text('Langue du téléphone'), findsOneWidget);
    });

    testWidgets('languageCode fr → Français', (tester) async {
      await tester.pumpWidget(
        _wrap(prefs: const UserPreferencesModel(languageCode: 'fr')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Français'), findsOneWidget);
    });

    testWidgets('languageCode en, anglais coupé → Français', (tester) async {
      // Interrupteur forcé à `false` : `kEnglishEnabled` vaut `true` depuis
      // l'activation, ce test vérifie le comportement replié explicitement.
      AppL10n.debugEnglishEnabled = false;
      addTearDown(() => AppL10n.debugEnglishEnabled = null);
      await tester.pumpWidget(
        _wrap(prefs: const UserPreferencesModel(languageCode: 'en')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Français'), findsOneWidget);
      expect(find.text('English'), findsNothing);
    });

    testWidgets('languageCode en, anglais activé → English', (tester) async {
      enableEnglish();
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

      // Le sélecteur s'ouvre avec ses choix (« anglais coupé » : voir le
      // test dédié ci-dessous pour la couverture précise de ce cas).
      expect(find.byType(ListTile), findsWidgets);
      expect(find.text('Français'), findsOneWidget);
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

    testWidgets('tap CGU tile navigates to /legal/terms', (tester) async {
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
      'tap Politique de confidentialité tile navigates to /legal/privacy',
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
        enableEnglish();
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

    testWidgets(
      'Réglages : la liste contient English et la sélection change la '
      'langue sans redémarrer',
      (tester) async {
        // Câblage identique à `MaterialApp.router` dans `lib/app/app.dart` :
        // un vrai AppPreferencesBloc, pas de mock, pour vérifier que le
        // changement de langue se propage jusqu'au texte affiché sans
        // reconstruire l'arbre de widgets (pas de redémarrage).
        final box = MockBox();
        when(
          () => box.get(any(), defaultValue: any(named: 'defaultValue')),
        ).thenAnswer((inv) => inv.namedArguments[#defaultValue]);
        when(
          () => box.get(
            HiveService.kLanguageCode,
            defaultValue: any(named: 'defaultValue'),
          ),
        ).thenReturn('fr');
        when(() => box.put(any(), any())).thenAnswer((_) async {});
        final bloc = AppPreferencesBloc(box);
        addTearDown(bloc.close);
        addTearDown(() => Intl.defaultLocale = null);

        await tester.pumpWidget(_wrapReal(bloc));
        await tester.pumpAndSettle();
        expect(find.text('Paramètres'), findsOneWidget);

        await tester.tap(find.text('Langue'));
        await tester.pumpAndSettle();
        expect(find.text('English'), findsOneWidget);

        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();

        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Paramètres'), findsNothing);
      },
    );

    testWidgets('language picker — anglais coupé : pas de choix English', (
      tester,
    ) async {
      // Interrupteur forcé à `false` : `kEnglishEnabled` vaut `true` depuis
      // l'activation, ce test vérifie le comportement replié explicitement.
      AppL10n.debugEnglishEnabled = false;
      addTearDown(() => AppL10n.debugEnglishEnabled = null);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Langue'));
      await tester.pumpAndSettle();

      expect(find.text('English'), findsNothing);
      expect(find.text('Langue du téléphone'), findsNWidgets(2));
    });

    testWidgets('anglais : titre, sections et tuiles traduits', (tester) async {
      useEnglish();
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('LANGUAGE & COMMUNICATION'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('My data'), findsOneWidget);
      expect(find.text('Paramètres'), findsNothing);
    });

    testWidgets('anglais : Aucune destination → None', (tester) async {
      useEnglish();
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('None'), findsOneWidget);
    });

    testWidgets(
      'language picker — tap Langue du téléphone dispatches LanguageChanged(system)',
      (tester) async {
        final mockBloc = MockAppPreferencesBloc();
        const state = AppPreferencesState(
          preferences: UserPreferencesModel(languageCode: 'fr'),
        );
        when(() => mockBloc.state).thenReturn(state);
        whenListen<AppPreferencesState>(
          mockBloc,
          const Stream.empty(),
          initialState: state,
        );

        await tester.pumpWidget(_wrapWithBloc(mockBloc));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Langue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Langue du téléphone'));
        await tester.pump();

        verify(() => mockBloc.add(const LanguageChanged('system'))).called(1);
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
      GoRoute(path: '/legal/terms', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/legal/privacy', builder: (_, _) => const Scaffold()),
      GoRoute(
        path: '/settings/diagnostics',
        builder: (_, _) => const Scaffold(),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}
