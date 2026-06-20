import 'package:dony/core/design/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// Mirrors _ActivityTab hub gating in profile_screen.dart (isTraveler → /trajets-colis, else isSender → /mes-colis, else nothing).
Widget _activityHubTile({
  required bool isTraveler,
  required bool isSender,
  int upcoming = 0,
}) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(
        path: '/test',
        builder: (context, state) {
          Widget hubTile;
          if (isTraveler) {
            hubTile = TextButton(
              onPressed: () => context.push(
                '/trajets-colis',
                extra: (upcomingCount: upcoming, isSender: isSender),
              ),
              child: const Text('Mes trajets et colis'),
            );
          } else if (isSender) {
            hubTile = TextButton(
              onPressed: () => context.push('/mes-colis'),
              child: const Text('Mes colis'),
            );
          } else {
            hubTile = const SizedBox.shrink();
          }
          return Scaffold(body: Center(child: hubTile));
        },
      ),
      GoRoute(
        path: '/trajets-colis',
        builder: (context, state) => const Scaffold(body: Text('TRAJETS_COLIS')),
      ),
      GoRoute(
        path: '/mes-colis',
        builder: (context, state) => const Scaffold(body: Text('MES_COLIS')),
      ),
    ],
  );
  return MaterialApp.router(
    theme: AppTheme.light,
    routerConfig: router,
  );
}

void main() {
  group('Profile hub gating', () {
    testWidgets('traveler-only → tile label « Mes trajets et colis »',
        (tester) async {
      await tester.pumpWidget(
        _activityHubTile(isTraveler: true, isSender: false),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Mes trajets et colis'), findsOneWidget);
      expect(find.text('Mes colis'), findsNothing);
    });

    testWidgets('both roles → tile label « Mes trajets et colis »',
        (tester) async {
      await tester.pumpWidget(
        _activityHubTile(isTraveler: true, isSender: true),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Mes trajets et colis'), findsOneWidget);
      expect(find.text('Mes colis'), findsNothing);
    });

    testWidgets('sender-only → tile label « Mes colis »', (tester) async {
      await tester.pumpWidget(
        _activityHubTile(isTraveler: false, isSender: true),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Mes colis'), findsOneWidget);
      expect(find.text('Mes trajets et colis'), findsNothing);
    });

    testWidgets(
        'traveler-only tile → tapping navigates to /trajets-colis',
        (tester) async {
      await tester.pumpWidget(
        _activityHubTile(isTraveler: true, isSender: false),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.tap(find.text('Mes trajets et colis'));
      await tester.pumpAndSettle();

      expect(find.text('TRAJETS_COLIS'), findsOneWidget);
    });

    testWidgets(
        'sender-only tile → tapping navigates to /mes-colis',
        (tester) async {
      await tester.pumpWidget(
        _activityHubTile(isTraveler: false, isSender: true),
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.tap(find.text('Mes colis'));
      await tester.pumpAndSettle();

      expect(find.text('MES_COLIS'), findsOneWidget);
    });

    testWidgets('neither role → no hub tile rendered', (tester) async {
      await tester.pumpWidget(_activityHubTile(isTraveler: false, isSender: false));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Mes trajets et colis'), findsNothing);
      expect(find.text('Mes colis'), findsNothing);
    });
  });
}
