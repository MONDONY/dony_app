import 'package:dony/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _wrap() => MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/delete-account',
            builder: (_, __) =>
                const Scaffold(body: Text('DeleteAccountScreen')),
          ),
        ],
      ),
    );

void main() {
  testWidgets('renders Paramètres title', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Paramètres'), findsOneWidget);
  });

  testWidgets('shows Supprimer mon compte tile', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Supprimer mon compte'), findsOneWidget);
  });

  testWidgets('tapping Supprimer mon compte navigates to delete-account screen',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Supprimer mon compte'));
    await tester.pumpAndSettle();

    expect(find.text('DeleteAccountScreen'), findsOneWidget);
  });
}
