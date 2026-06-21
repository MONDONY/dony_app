import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/profile/presentation/screens/mes_colis_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _buildHarness() {
  final router = GoRouter(
    initialLocation: '/mes-colis',
    routes: [
      GoRoute(
        path: '/mes-colis',
        builder: (_, __) => const MesColisScreen(),
      ),
      GoRoute(
        path: '/corridor-alerts',
        builder: (_, __) => const Scaffold(body: Text('CORRIDOR_ALERTS')),
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

void main() {
  group('MesColisScreen', () {
    testWidgets('renders the two sender hub rows', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Mes destinataires'), findsOneWidget);
      expect(find.text('Mes alertes trajets'), findsOneWidget);
    });

    testWidgets('does not show traveler-only or duplicate rows', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump(const Duration(milliseconds: 600));

      // « Mes demandes de colis » vit déjà dans l'onglet Activité (doublon)
      expect(find.text('Mes demandes de colis'), findsNothing);
      // « Mes adresses » est réservé au voyageur
      expect(find.text('Mes adresses'), findsNothing);
    });

    testWidgets('renders AppBar title "Mes colis"', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Mes colis'), findsOneWidget);
    });

    testWidgets(
      'tapping "Mes destinataires" navigates to /profile/recipients',
      (tester) async {
        await tester.pumpWidget(_buildHarness());
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await tester.tap(find.text('Mes destinataires'));
        await tester.pumpAndSettle();

        expect(find.text('RECIPIENTS'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping "Mes alertes trajets" navigates to /corridor-alerts',
      (tester) async {
        await tester.pumpWidget(_buildHarness());
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await tester.tap(find.text('Mes alertes trajets'));
        await tester.pumpAndSettle();

        expect(find.text('CORRIDOR_ALERTS'), findsOneWidget);
      },
    );
  });
}
