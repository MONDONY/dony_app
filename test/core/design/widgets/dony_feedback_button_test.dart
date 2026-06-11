import 'package:dony/core/design/design_system.dart';
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
}
