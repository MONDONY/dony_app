import 'package:dony/features/settings/presentation/widgets/escrow_block_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../helpers/l10n_test_helpers.dart';

Widget _wrap() => MaterialApp.router(
  routerConfig: GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => EscrowBlockDialog.show(ctx),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/announcements',
        builder: (_, _) => const Scaffold(body: Text('Announcements')),
      ),
    ],
  ),
);

void main() {
  testWidgets('shows title and explanation', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Suppression impossible pour l\'instant'), findsOneWidget);
    expect(find.textContaining('fonds'), findsOneWidget);
  });

  testWidgets('Fermer button closes the dialog', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    expect(find.text('Suppression impossible pour l\'instant'), findsNothing);
  });

  testWidgets('Voir mes envois button closes dialog and navigates', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voir mes envois'));
    await tester.pumpAndSettle();

    expect(find.text('Announcements'), findsOneWidget);
  });

  group('anglais', () {
    testWidgets('titre, message et boutons traduits', (tester) async {
      useEnglish();
      await tester.pumpWidget(_wrap());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Deletion isn\'t possible right now'), findsOneWidget);
      expect(
        find.textContaining(
          'One of your shipments is being delivered and its funds are on '
          'hold.',
        ),
        findsOneWidget,
      );
      expect(find.text('View my shipments'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('View my shipments navigates', (tester) async {
      useEnglish();
      await tester.pumpWidget(_wrap());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View my shipments'));
      await tester.pumpAndSettle();

      expect(find.text('Announcements'), findsOneWidget);
    });
  });
}
