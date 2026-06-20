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
        path: '/package-requests/me',
        builder: (_, __) => const Scaffold(body: Text('MES_DEMANDES')),
      ),
      GoRoute(
        path: '/corridor-alerts',
        builder: (_, __) => const Scaffold(body: Text('CORRIDOR_ALERTS')),
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

      expect(find.text('Mes demandes de colis'), findsOneWidget);
      expect(find.text('Mes alertes corridor'), findsOneWidget);
    });

    testWidgets('renders AppBar title "Mes colis"', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Mes colis'), findsOneWidget);
    });

    testWidgets(
      'tapping "Mes demandes de colis" navigates to /package-requests/me',
      (tester) async {
        await tester.pumpWidget(_buildHarness());
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await tester.tap(find.text('Mes demandes de colis'));
        await tester.pumpAndSettle();

        expect(find.text('MES_DEMANDES'), findsOneWidget);
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
  });
}
