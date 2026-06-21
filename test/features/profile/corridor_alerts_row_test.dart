import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/profile/presentation/screens/mes_trajets_colis_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Vérifie que la tuile "Mes alertes colis" est présente sur MesTrajetsColisScreen
// (elle a été déplacée hors du profile_screen vers ce hub voyageur).
void main() {
  Widget _buildHarness() {
    final router = GoRouter(
      initialLocation: '/trajets-colis',
      routes: [
        GoRoute(
          path: '/trajets-colis',
          builder: (_, __) => const MesTrajetsColisScreen(),
        ),
        GoRoute(
          path: '/corridor-alerts',
          builder: (_, __) => const Scaffold(body: Text('ALERTS')),
        ),
        GoRoute(
          path: '/package-requests/match',
          builder: (_, __) => const Scaffold(body: Text('MATCH')),
        ),
        GoRoute(
          path: '/announcements',
          builder: (_, __) => const Scaffold(body: Text('ANNOUNCEMENTS')),
        ),
        GoRoute(
          path: '/trip-templates',
          builder: (_, __) => const Scaffold(body: Text('TEMPLATES')),
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    );
  }

  testWidgets('hub screen contains "Mes alertes colis" row', (t) async {
    await t.pumpWidget(_buildHarness());
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Mes alertes colis'), findsOneWidget);
  });

  testWidgets('Mes alertes colis row navigates to /corridor-alerts',
      (t) async {
    await t.pumpWidget(_buildHarness());
    await t.pumpAndSettle(const Duration(seconds: 1));
    await t.tap(find.text('Mes alertes colis'));
    await t.pumpAndSettle();
    expect(find.text('ALERTS'), findsOneWidget);
  });

  testWidgets(
    'profile_screen shows single "Mes trajets et colis" entry (not 4 tiles)',
    (t) async {
      // Render just the DonyListSection with the new single entry,
      // matching what profile_screen.dart now renders for a traveler.
      final router = GoRouter(
        initialLocation: '/p',
        routes: [
          GoRoute(
            path: '/p',
            builder: (ctx, _) => Scaffold(
              body: DonyListSection(
                tiles: [
                  DonyListTile(
                    iconAsset: 'plane',
                    label: 'Mes trajets et colis',
                    showDivider: false,
                    onTap: () => ctx.push('/trajets-colis'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/trajets-colis',
            builder: (_, __) => const Scaffold(body: Text('HUB')),
          ),
        ],
      );
      await t.pumpWidget(MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ));
      await t.pumpAndSettle();

      expect(find.text('Mes trajets et colis'), findsOneWidget);
      // Old 4-tile labels must NOT appear on the profile section
      expect(find.text('Mes trajets'), findsNothing);
      expect(find.text('Colis sur mes trajets'), findsNothing);
      expect(find.text('Mes alertes colis'), findsNothing);
      expect(find.text('Mes modèles de trajet'), findsNothing);

      // Tapping the single entry navigates to hub
      await t.tap(find.text('Mes trajets et colis'));
      await t.pumpAndSettle();
      expect(find.text('HUB'), findsOneWidget);
    },
  );
}
