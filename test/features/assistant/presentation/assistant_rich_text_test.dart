import 'package:dony/features/assistant/presentation/widgets/assistant_rich_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rendu maison du texte riche de l'assistant (YADONY-FLUTTER-PROD-13).
void main() {
  const style = TextStyle(fontSize: 15, height: 1.45);

  Future<void> pump(
    WidgetTester tester,
    String text, {
    ThemeData? theme,
    double scale = 1,
    double width = 320,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        // Comme dans la conversation : la bulle vit dans une liste qui défile.
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: Builder(
                builder: (context) => AssistantRichText(
                  text,
                  style: style.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  List<TextSpan> spansOf(WidgetTester tester, String containing) {
    final rich = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((r) => r.text.toPlainText().contains(containing));
    final out = <TextSpan>[];
    rich.text.visitChildren((span) {
      if (span is TextSpan && (span.text ?? '').isNotEmpty) out.add(span);
      return true;
    });
    return out;
  }

  testWidgets('gras : segment en w700, balises invisibles', (tester) async {
    await pump(tester, 'Délai de **48 h** pour confirmer.');
    final spans = spansOf(tester, '48 h');
    final bold = spans.firstWhere((s) => s.text == '48 h');
    expect(bold.style!.fontWeight, FontWeight.w700);
    expect(find.textContaining('**'), findsNothing);
    expect(spans.map((s) => s.text).join(), 'Délai de 48 h pour confirmer.');
  });

  testWidgets('puces : une ligne par élément, puce + texte', (tester) async {
    await pump(
      tester,
      'Voici :\n- Ouvrez **Portefeuille**\n- Touchez Recharger',
    );
    expect(find.text('•'), findsNWidgets(2));
    expect(find.byType(Row), findsNWidgets(2));
    expect(find.textContaining('- '), findsNothing);
    expect(find.textContaining('Touchez Recharger'), findsOneWidget);
  });

  testWidgets('texte sans balise : un seul paragraphe, inchangé', (
    tester,
  ) async {
    await pump(tester, 'Allez dans Moi.');
    expect(find.text('Allez dans Moi.'), findsOneWidget);
    expect(find.byType(Row), findsNothing);
  });

  testWidgets('paragraphes espacés, lignes vides ignorées', (tester) async {
    await pump(tester, 'Un.\n\n\nDeux.');
    expect(find.text('Un.'), findsOneWidget);
    expect(find.text('Deux.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Deux.')).dy -
          tester.getBottomLeft(find.text('Un.')).dy,
      greaterThanOrEqualTo(8),
    );
  });

  testWidgets('** orphelines : affichées telles quelles, sans planter', (
    tester,
  ) async {
    await pump(tester, 'Prix **12 € et ** fin **');
    expect(tester.takeException(), isNull);
    final spans = spansOf(tester, '12 €');
    expect(
      spans.firstWhere((s) => s.text!.contains('12 €')).style?.fontWeight,
      FontWeight.w700,
    );
    expect(spans.map((s) => s.text).join(), 'Prix 12 € et  fin **');
  });

  testWidgets('thème sombre : couleur du texte = onSurface', (tester) async {
    final dark = ThemeData(brightness: Brightness.dark);
    await pump(tester, 'Ouvrez **Moi**.', theme: dark);
    final rich = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((r) => r.text.toPlainText().contains('Moi'));
    expect(rich.text.style!.color, dark.colorScheme.onSurface);
  });

  testWidgets('textScaler 2.0 sur un écran étroit : aucun débordement', (
    tester,
  ) async {
    await pump(
      tester,
      'Réponse directe assez longue pour passer à la ligne.\n'
      '- Étape avec un **nom de bouton** un peu long\n'
      '- Deuxième étape qui déborderait sans retour à la ligne',
      scale: 2,
      width: 200,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('lecteur d’écran : texte brut, sans balise', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, 'Allez dans **Moi**.\n- Touchez **Profil**');
    expect(
      find.bySemanticsLabel('Allez dans Moi.\n• Touchez Profil'),
      findsOneWidget,
    );
    handle.dispose();
  });

  test('assistantPlainText retire seulement les balises appariées', () {
    expect(assistantPlainText('a **b** **c'), 'a b **c');
    expect(assistantPlainText('- x\n\n- **y**'), '• x\n• y');
  });
}
