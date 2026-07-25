import 'package:dony/core/design/theme/app_theme.dart';
import 'package:dony/features/matching/presentation/widgets/cancellation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Builds a [GoRouter] that shows [CancellationDialog] as a dialog on the
/// root route and stores the result in [result].
GoRouter _buildRouter({
  required CancellationKind kind,
  required ValueNotifier<String?> result,
}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                final value =
                    await CancellationDialog.show(ctx, kind: kind);
                result.value = value;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ],
  );
}

Future<void> _pumpAndOpenDialog(
  WidgetTester tester, {
  required CancellationKind kind,
  required ValueNotifier<String?> result,
}) async {
  await tester.pumpWidget(MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: _buildRouter(kind: kind, result: result),
  ));
  await tester.pump();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('CancellationDialog', () {
    // ── Layout ──────────────────────────────────────────────────────────────

    testWidgets('shows optional hint text when isInTransit is false',
        (tester) async {
      final result = ValueNotifier<String?>(null);
      await _pumpAndOpenDialog(tester, kind: CancellationKind.accepted, result: result);

      // Le champ motif affiche le hint "Motif (optionnel)"
      expect(find.text('Motif (optionnel)'), findsOneWidget);
    });

    testWidgets('shows mandatory hint text when isInTransit is true',
        (tester) async {
      final result = ValueNotifier<String?>(null);
      await _pumpAndOpenDialog(tester, kind: CancellationKind.afterHandover, result: result);

      expect(find.text("Motif de l'annulation *"), findsOneWidget);
    });

    testWidgets('shows warning box when isInTransit is true', (tester) async {
      final result = ValueNotifier<String?>(null);
      await _pumpAndOpenDialog(tester, kind: CancellationKind.afterHandover, result: result);

      expect(find.textContaining('restituer'), findsOneWidget);
      expect(find.textContaining('code de retour'), findsOneWidget);
      // Disclaimer espèces : aucun mouvement d'argent.
      expect(find.textContaining("aucun mouvement d'argent"), findsOneWidget);
    });

    testWidgets('does NOT show warning box when isInTransit is false',
        (tester) async {
      final result = ValueNotifier<String?>(null);
      await _pumpAndOpenDialog(tester, kind: CancellationKind.accepted, result: result);

      expect(find.textContaining('restituer'), findsNothing);
    });

    testWidgets('shows refund subtitle when isInTransit is false',
        (tester) async {
      final result = ValueNotifier<String?>(null);
      await _pumpAndOpenDialog(tester, kind: CancellationKind.accepted, result: result);

      expect(
        find.textContaining('remboursé automatiquement'),
        findsOneWidget,
      );
    });

    // ── "Garder" button ──────────────────────────────────────────────────────

    testWidgets(
        'tapping "Garder" dismisses the dialog and result is null (ACCEPTED)',
        (tester) async {
      final result = ValueNotifier<String?>(null);
      await _pumpAndOpenDialog(tester, kind: CancellationKind.accepted, result: result);

      await tester.tap(find.text('Garder'));
      await tester.pumpAndSettle();

      // Dialog is gone
      expect(find.text('Annuler cette demande ?'), findsNothing);
      // result stays null (not set to '' — only set on confirm)
      expect(result.value, isNull);
    });

    testWidgets(
        'tapping "Garder" dismisses the dialog and result is null (IN_TRANSIT)',
        (tester) async {
      final result = ValueNotifier<String?>(null);
      await _pumpAndOpenDialog(tester, kind: CancellationKind.afterHandover, result: result);

      await tester.tap(find.text('Garder'));
      await tester.pumpAndSettle();

      expect(find.text('Annuler cette demande ?'), findsNothing);
      expect(result.value, isNull);
    });

    // ── "Annuler la demande" — ACCEPTED (kind: CancellationKind.accepted) ────────────────

    testWidgets(
        'tapping "Annuler la demande" with empty reason in ACCEPTED returns ""',
        (tester) async {
      final result = ValueNotifier<String?>(null);
      await _pumpAndOpenDialog(tester, kind: CancellationKind.accepted, result: result);

      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();

      expect(find.text('Annuler cette demande ?'), findsNothing);
      expect(result.value, equals(''));
    });

    testWidgets(
        'tapping "Annuler la demande" with filled reason in ACCEPTED returns the reason',
        (tester) async {
      final result = ValueNotifier<String?>(null);
      await _pumpAndOpenDialog(tester, kind: CancellationKind.accepted, result: result);

      await tester.enterText(find.byType(TextField), 'Bagages complets');
      await tester.pump();

      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();

      expect(result.value, equals('Bagages complets'));
    });

    // ── "Annuler la demande" — IN_TRANSIT (kind: CancellationKind.afterHandover) ───────────────

    testWidgets(
        'tapping "Annuler la demande" with empty reason in IN_TRANSIT shows error',
        (tester) async {
      final result = ValueNotifier<String?>(null);
      await _pumpAndOpenDialog(tester, kind: CancellationKind.afterHandover, result: result);

      // Confirm without typing anything
      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();

      // Dialog remains open and shows validation error
      expect(find.text('Annuler cette demande ?'), findsOneWidget);
      expect(find.text('Motif requis'), findsOneWidget);
      // result not set
      expect(result.value, isNull);
    });

    testWidgets(
        'tapping "Annuler la demande" with filled reason in IN_TRANSIT returns reason',
        (tester) async {
      final result = ValueNotifier<String?>(null);
      await _pumpAndOpenDialog(tester, kind: CancellationKind.afterHandover, result: result);

      await tester.enterText(find.byType(TextField), 'Colis trop lourd');
      await tester.pump();

      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();

      expect(find.text('Annuler cette demande ?'), findsNothing);
      expect(result.value, equals('Colis trop lourd'));
    });

    testWidgets(
        'error clears when user starts typing after failed IN_TRANSIT confirm',
        (tester) async {
      final result = ValueNotifier<String?>(null);
      await _pumpAndOpenDialog(tester, kind: CancellationKind.afterHandover, result: result);

      // Trigger error
      await tester.tap(find.text('Annuler la demande'));
      await tester.pumpAndSettle();
      expect(find.text('Motif requis'), findsOneWidget);

      // Start typing — error should disappear
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump();

      expect(find.text('Motif requis'), findsNothing);
    });

    // ── Buttons present ──────────────────────────────────────────────────────

    testWidgets('dialog shows both action buttons', (tester) async {
      final result = ValueNotifier<String?>(null);
      await _pumpAndOpenDialog(tester, kind: CancellationKind.accepted, result: result);

      expect(find.text('Garder'), findsOneWidget);
      expect(find.text('Annuler la demande'), findsOneWidget);
    });

    testWidgets('dialog title is always visible', (tester) async {
      final result = ValueNotifier<String?>(null);
      await _pumpAndOpenDialog(tester, kind: CancellationKind.accepted, result: result);

      expect(find.text('Annuler cette demande ?'), findsOneWidget);
    });
  });
}
