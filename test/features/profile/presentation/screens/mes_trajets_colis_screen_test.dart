import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/profile/presentation/screens/mes_trajets_colis_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _buildHarness({int upcomingCount = 0, bool isSender = false}) {
  final router = GoRouter(
    initialLocation: '/trajets-colis',
    routes: [
      GoRoute(
        path: '/trajets-colis',
        builder: (_, __) => MesTrajetsColisScreen(
          upcomingCount: upcomingCount,
          isSender: isSender,
        ),
      ),
      GoRoute(
        path: '/announcements',
        builder: (_, __) => const Scaffold(body: Text('ANNOUNCEMENTS')),
      ),
      GoRoute(
        path: '/package-requests/match',
        builder: (_, __) => const Scaffold(body: Text('COLIS_MATCH')),
      ),
      GoRoute(
        path: '/package-requests/me',
        builder: (_, __) => const Scaffold(body: Text('MES_DEMANDES')),
      ),
      GoRoute(
        path: '/corridor-alerts',
        builder: (_, __) => const Scaffold(body: Text('CORRIDOR_ALERTS')),
      ),
      GoRoute(
        path: '/trip-templates',
        builder: (_, __) => const Scaffold(body: Text('TRIP_TEMPLATES')),
      ),
      GoRoute(
        path: '/profile/addresses',
        builder: (_, __) => const Scaffold(body: Text('ADDRESSES')),
      ),
      GoRoute(
        path: '/profile/recipients',
        builder: (_, __) => const Scaffold(body: Text('RECIPIENTS')),
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
    testWidgets('renders AppBar title and VOYAGEUR block labels', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Mes trajets et colis'), findsOneWidget);
      expect(find.text('VOYAGEUR · TRAJETS'), findsOneWidget);
      expect(find.text('Mes trajets'), findsOneWidget);
      expect(find.text('Colis sur mes trajets'), findsOneWidget);
      expect(find.text('Mes alertes colis'), findsOneWidget);
      expect(find.text('Mes modèles de trajet'), findsOneWidget);
      expect(find.text('Mes adresses'), findsOneWidget);
    });

    testWidgets('shows "X actifs" badge when upcomingCount > 0', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHarness(upcomingCount: 3));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('3 actifs'), findsOneWidget);
    });

    testWidgets('no "actifs" badge when upcomingCount == 0', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.textContaining('actifs'), findsNothing);
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
      'tapping "Mes alertes colis" navigates to /corridor-alerts',
      (tester) async {
        await tester.pumpWidget(_buildHarness());
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await tester.tap(find.text('Mes alertes colis'));
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

    testWidgets('tapping "Mes adresses" navigates to /profile/addresses', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.tap(find.text('Mes adresses'));
      await tester.pumpAndSettle();

      expect(find.text('ADDRESSES'), findsOneWidget);
    });

    testWidgets(
      'isSender:true shows EXPÉDITEUR block with alertes + destinataires (no demandes)',
      (tester) async {
        await tester.pumpWidget(_buildHarness(isSender: true));
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('EXPÉDITEUR · COLIS'), findsOneWidget);
        expect(find.text('Mes destinataires'), findsOneWidget);
        // Alertes renommées par direction : colis (voyageur) + trajets (expéditeur).
        expect(find.text('Mes alertes colis'), findsOneWidget);
        expect(find.text('Mes alertes trajets'), findsOneWidget);
        // « Mes demandes de colis » retiré : déjà accessible via le hub Envoyer.
        expect(find.text('Mes demandes de colis'), findsNothing);
      },
    );

    testWidgets(
      'isSender:false hides the entire EXPÉDITEUR block',
      (tester) async {
        await tester.pumpWidget(_buildHarness(isSender: false));
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('EXPÉDITEUR · COLIS'), findsNothing);
        expect(find.text('Mes demandes de colis'), findsNothing);
        expect(find.text('Mes destinataires'), findsNothing);
      },
    );

    testWidgets(
      'isSender:true — tapping "Mes destinataires" navigates to /profile/recipients',
      (tester) async {
        await tester.pumpWidget(_buildHarness(isSender: true));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await tester.tap(find.text('Mes destinataires'));
        await tester.pumpAndSettle();

        expect(find.text('RECIPIENTS'), findsOneWidget);
      },
    );
  });
}
