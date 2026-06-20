import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/profile/presentation/screens/mes_trajets_colis_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _buildHarness({int upcomingCount = 0}) {
  final router = GoRouter(
    initialLocation: '/trajets-colis',
    routes: [
      GoRoute(
        path: '/trajets-colis',
        builder: (_, __) =>
            MesTrajetsColisScreen(upcomingCount: upcomingCount),
      ),
      GoRoute(
        path: '/announcements',
        builder: (_, __) =>
            const Scaffold(body: Text('ANNOUNCEMENTS')),
      ),
      GoRoute(
        path: '/package-requests/match',
        builder: (_, __) =>
            const Scaffold(body: Text('COLIS_MATCH')),
      ),
      GoRoute(
        path: '/corridor-alerts',
        builder: (_, __) =>
            const Scaffold(body: Text('CORRIDOR_ALERTS')),
      ),
      GoRoute(
        path: '/trip-templates',
        builder: (_, __) =>
            const Scaffold(body: Text('TRIP_TEMPLATES')),
      ),
    ],
  );
  return MaterialApp.router(
    theme: AppTheme.light,
    routerConfig: router,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('MesTrajetsColisScreen', () {
    testWidgets('renders AppBar title and all 4 row labels', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Mes trajets et colis'), findsOneWidget);
      expect(find.text('Mes trajets'), findsOneWidget);
      expect(find.text('Colis sur mes trajets'), findsOneWidget);
      expect(find.text('Mes alertes corridor'), findsOneWidget);
      expect(find.text('Mes modèles de trajet'), findsOneWidget);
    });

    testWidgets('shows "X à venir" badge when upcomingCount > 0', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHarness(upcomingCount: 3));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('3 à venir'), findsOneWidget);
    });

    testWidgets('no "à venir" badge when upcomingCount == 0', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('à venir'), findsNothing);
    });

    testWidgets('tapping "Mes trajets" navigates to /announcements', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.tap(find.text('Mes trajets'));
      await tester.pumpAndSettle();

      expect(find.text('ANNOUNCEMENTS'), findsOneWidget);
    });

    testWidgets(
      'tapping "Colis sur mes trajets" navigates to /package-requests/match',
      (tester) async {
        await tester.pumpWidget(_buildHarness());
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await tester.tap(find.text('Colis sur mes trajets'));
        await tester.pumpAndSettle();

        expect(find.text('COLIS_MATCH'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping "Mes alertes corridor" navigates to /corridor-alerts',
      (tester) async {
        await tester.pumpWidget(_buildHarness());
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await tester.tap(find.text('Mes alertes corridor'));
        await tester.pumpAndSettle();

        expect(find.text('CORRIDOR_ALERTS'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping "Mes modèles de trajet" navigates to /trip-templates',
      (tester) async {
        await tester.pumpWidget(_buildHarness());
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await tester.tap(find.text('Mes modèles de trajet'));
        await tester.pumpAndSettle();

        expect(find.text('TRIP_TEMPLATES'), findsOneWidget);
      },
    );
  });
}
