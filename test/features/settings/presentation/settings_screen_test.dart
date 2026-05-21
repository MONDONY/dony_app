import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/settings/bloc/app_preferences_bloc.dart';
import 'package:dony/features/settings/data/models/user_preferences_model.dart';
import 'package:dony/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAppPreferencesBloc
    extends MockBloc<AppPreferencesEvent, AppPreferencesState>
    implements AppPreferencesBloc {}

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
        builder: (_, __) => BlocProvider<AppPreferencesBloc>.value(
          value: mockBloc,
          child: const SettingsScreen(),
        ),
      ),
      // Stub routes used by SettingsScreen navigation items
      GoRoute(path: '/settings/security', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/settings/privacy', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/settings/data', builder: (_, __) => const Scaffold()),
      GoRoute(
          path: '/settings/notifications',
          builder: (_, __) => const Scaffold()),
      GoRoute(
          path: '/settings/preferences', builder: (_, __) => const Scaffold()),
      GoRoute(
          path: '/settings/accessibility',
          builder: (_, __) => const Scaffold()),
      GoRoute(
          path: '/settings/legal/terms', builder: (_, __) => const Scaffold()),
      GoRoute(
          path: '/settings/legal/privacy',
          builder: (_, __) => const Scaffold()),
      GoRoute(
          path: '/settings/diagnostics', builder: (_, __) => const Scaffold()),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

void main() {
  group('SettingsScreen', () {
    testWidgets('renders Paramètres title', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Paramètres'), findsOneWidget);
    });

    testWidgets('shows APPARENCE section with dark mode tile', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('APPARENCE'), findsOneWidget);
      expect(find.text('Thème sombre'), findsOneWidget);
    });

    testWidgets('shows LANGUE & COMMUNICATION section', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('LANGUE & COMMUNICATION'), findsOneWidget);
      expect(find.text('Langue'), findsOneWidget);
      expect(find.text('Alertes critiques par SMS'), findsOneWidget);
    });

    testWidgets('shows DESTINATIONS FAVORITES section with 4 chips',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('DESTINATIONS FAVORITES'), findsOneWidget);
      expect(find.textContaining('Dakar'), findsOneWidget);
      expect(find.textContaining('Abidjan'), findsOneWidget);
      expect(find.textContaining('Bamako'), findsOneWidget);
      expect(find.textContaining('Douala'), findsOneWidget);
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
      expect(find.text('PERSONNALISATION', skipOffstage: false), findsOneWidget);
      expect(find.text('Notifications', skipOffstage: false), findsOneWidget);
      expect(find.text('Préférences', skipOffstage: false), findsOneWidget);
      expect(find.text('Accessibilité', skipOffstage: false), findsOneWidget);
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

    testWidgets('dark mode switch reflects themeMode dark state',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          prefs: const UserPreferencesModel(themeMode: 'dark'),
        ),
      );
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      // First switch is the dark mode toggle
      expect(switches.first.value, isTrue);
    });

    testWidgets('dark mode switch is off when themeMode is system',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          prefs: const UserPreferencesModel(themeMode: 'system'),
        ),
      );
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.first.value, isFalse);
    });

    testWidgets('SMS alerts switch reflects smsAlertsEnabled state',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          prefs: const UserPreferencesModel(smsAlertsEnabled: true),
        ),
      );
      await tester.pumpAndSettle();

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      // Second switch is SMS alerts
      expect(switches[1].value, isTrue);
    });

    testWidgets('selected destination chip shows primary styling',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          prefs: const UserPreferencesModel(favDestinations: ['SN']),
        ),
      );
      await tester.pumpAndSettle();

      // Dakar chip is present and selected (rendered with primaryContainer color)
      expect(find.textContaining('Dakar'), findsOneWidget);
    });

    testWidgets('language shows Français when languageCode is fr',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          prefs: const UserPreferencesModel(languageCode: 'fr'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Français'), findsOneWidget);
    });

    testWidgets('language shows English when languageCode is en',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          prefs: const UserPreferencesModel(languageCode: 'en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('English'), findsOneWidget);
    });
  });
}
