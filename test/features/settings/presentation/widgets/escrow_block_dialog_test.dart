import 'package:dony/features/settings/presentation/widgets/escrow_block_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _wrap() => MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => showDialog(
                    context: ctx,
                    builder: (_) => const EscrowBlockDialog(),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/announcements',
            builder: (_, __) => const Scaffold(body: Text('Announcements')),
          ),
        ],
      ),
    );

void main() {
  testWidgets('shows title and explanation', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Paiement en cours'), findsOneWidget);
    expect(find.textContaining('escrow'), findsOneWidget);
  });

  testWidgets('Fermer button closes the dialog', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    expect(find.text('Paiement en cours'), findsNothing);
  });

  testWidgets('Voir mes envois button closes dialog and navigates', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voir mes envois'));
    await tester.pumpAndSettle();

    expect(find.text('Announcements'), findsOneWidget);
  });
}
