import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/design/widgets/dony_feedback_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget subject({Future<void> Function(String message)? onSubmit}) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [DonyFeedbackButton(onSubmitOverride: onSubmit)],
        ),
        body: const SizedBox(),
      ),
    );
  }

  testWidgets('icône 🐞 visible avec tooltip', (tester) async {
    await tester.pumpWidget(subject());
    expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
    expect(find.byTooltip('Signaler un problème'), findsOneWidget);
  });

  testWidgets('tap ouvre le sheet avec champ texte et bouton désactivé', (tester) async {
    await tester.pumpWidget(subject());
    await tester.tap(find.byIcon(Icons.bug_report_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Un problème sur cet écran ?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    final btn = tester.widget<DonyButton>(
      find.widgetWithText(DonyButton, 'Envoyer le rapport'),
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('saisie active le bouton et l\'envoi appelle onSubmit', (tester) async {
    String? submitted;
    await tester.pumpWidget(subject(onSubmit: (m) async => submitted = m));
    await tester.tap(find.byIcon(Icons.bug_report_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Le code retrait ne s\'affiche pas');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le rapport'));
    await tester.pumpAndSettle();

    expect(submitted, 'Le code retrait ne s\'affiche pas');
    expect(find.text('Un problème sur cet écran ?'), findsNothing);
    expect(find.textContaining('Merci'), findsOneWidget);
  });

  testWidgets('échec onSubmit garde le texte et montre une erreur', (tester) async {
    await tester.pumpWidget(
      subject(onSubmit: (_) async => throw Exception('network')),
    );
    await tester.tap(find.byIcon(Icons.bug_report_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bug');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le rapport'));
    await tester.pumpAndSettle();

    expect(find.text('Un problème sur cet écran ?'), findsOneWidget);
    expect(find.text('bug'), findsOneWidget);
  });

  // ── Fallback path: resolveRoute retourne 'unknown' hors GoRouter ───────────

  testWidgets(
      'resolveRoute retourne "unknown" dans un contexte sans GoRouter',
      (tester) async {
    // GoRouterState.of(context) lève une exception dans un plain MaterialApp —
    // resolveRoute() doit capturer l'erreur et retourner 'unknown'.
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(builder: (ctx) {
          capturedContext = ctx;
          return const SizedBox();
        }),
      ),
    );
    expect(DonyFeedbackButton.resolveRoute(capturedContext), 'unknown');
  });

  testWidgets(
      'submit via onSubmitOverride dans un plain MaterialApp (sans GoRouter) '
      'ne lève pas d\'exception — chemin resolveRoute "unknown" exercé',
      (tester) async {
    // Ce test vérifie que la soumission complète fonctionne lorsqu'il n'y a
    // pas de GoRouter ancêtre. resolveRoute() retourne 'unknown' silencieusement.
    String? submitted;
    await tester.pumpWidget(subject(onSubmit: (m) async => submitted = m));
    await tester.tap(find.byIcon(Icons.bug_report_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'test sans GoRouter');
    await tester.pumpAndSettle();

    // Ne doit pas lancer d'exception même sans GoRouter dans l'arbre.
    await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le rapport'));
    await tester.pumpAndSettle();

    expect(submitted, 'test sans GoRouter');
  });

  // ── Fallback path: repaintBoundaryKey null → capture ignorée ──────────────

  testWidgets(
      'submit réussit sans crash quand repaintBoundaryKey est null '
      '(chemin _captureScreen → null exercé)', (tester) async {
    // DonyFeedbackButton sans repaintBoundaryKey (valeur par défaut = null) :
    // _captureScreen() doit retourner null sans exception, et la soumission
    // doit se terminer normalement.
    String? submitted;
    // subject() ne passe pas de repaintBoundaryKey → null par défaut.
    await tester.pumpWidget(subject(onSubmit: (m) async => submitted = m));
    await tester.tap(find.byIcon(Icons.bug_report_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bug sans capture');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DonyButton, 'Envoyer le rapport'));
    await tester.pumpAndSettle();

    // La soumission s'est bien terminée, le sheet est fermé.
    expect(submitted, 'bug sans capture');
    expect(find.text('Un problème sur cet écran ?'), findsNothing);
  });
}
