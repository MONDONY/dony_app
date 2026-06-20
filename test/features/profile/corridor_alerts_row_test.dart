import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Minimal harness: render just the MES TRAJETS DonyListSection shape used in
// profile_screen.dart so the row + nav are testable without the full screen.
void main() {
  testWidgets('Mes alertes corridor row navigates to /corridor-alerts',
      (t) async {
    final router = GoRouter(
      initialLocation: '/p',
      routes: [
        GoRoute(
          path: '/p',
          builder: (ctx, _) => Scaffold(
            body: DonyListSection(
              tiles: [
                DonyListTile(
                  iconAsset: 'inbox',
                  label: 'Colis sur mes trajets',
                  onTap: () => ctx.push('/package-requests/match'),
                ),
                DonyListTile(
                  iconAsset: 'bell',
                  label: 'Mes alertes corridor',
                  onTap: () => ctx.push('/corridor-alerts'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/corridor-alerts',
          builder: (_, __) => const Scaffold(body: Text('ALERTS')),
        ),
        GoRoute(
          path: '/package-requests/match',
          builder: (_, __) => const Scaffold(body: Text('MATCH')),
        ),
      ],
    );
    await t.pumpWidget(MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    ));
    await t.pumpAndSettle();
    expect(find.text('Mes alertes corridor'), findsOneWidget);
    await t.tap(find.text('Mes alertes corridor'));
    await t.pumpAndSettle();
    expect(find.text('ALERTS'), findsOneWidget);
  });
}
