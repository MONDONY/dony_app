// Carte du corps des fiches colis et trajet (DetailCard) : sans action, le
// rendu d'origine ; avec [trailing], l'action au bout de la ligne du titre ;
// avec [onTap], toute la carte tappable avec son encre.
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget card) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: card)),
    ),
  );

  Finder card() => find.byType(DetailCard);

  testWidgets('sans action : titre puis contenu, ni encre ni ligne d\'action', (
    tester,
  ) async {
    await pump(
      tester,
      const DetailCard(title: 'Titre', child: Text('Contenu')),
    );

    expect(find.text('Titre'), findsOneWidget);
    expect(find.text('Contenu'), findsOneWidget);
    expect(
      find.descendant(of: card(), matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.descendant(of: card(), matching: find.byType(Row)),
      findsNothing,
    );
    expect(
      tester.getTopLeft(find.text('Titre')).dy,
      lessThan(tester.getTopLeft(find.text('Contenu')).dy),
    );
  });

  testWidgets('trailing : au bout de la ligne du titre', (tester) async {
    await pump(
      tester,
      const SizedBox(
        width: 300,
        child: DetailCard(
          title: 'Titre',
          trailing: Text('Action'),
          child: Text('Contenu'),
        ),
      ),
    );

    final title = tester.getCenter(find.text('Titre'));
    final action = tester.getCenter(find.text('Action'));
    expect(action.dy, closeTo(title.dy, 1));
    expect(action.dx, greaterThan(title.dx));
    expect(
      tester.getTopLeft(find.text('Contenu')).dy,
      greaterThan(tester.getBottomLeft(find.text('Action')).dy),
    );
  });

  testWidgets('onTap : toute la carte tappable', (tester) async {
    var taps = 0;
    await pump(
      tester,
      DetailCard(
        title: 'Titre',
        onTap: () => taps++,
        child: const Text('Contenu'),
      ),
    );

    await tester.tap(find.text('Contenu'));
    await tester.tap(find.text('Titre'));
    expect(taps, 2);
    final ink = tester.widget<InkWell>(
      find.descendant(of: card(), matching: find.byType(InkWell)),
    );
    expect(ink.borderRadius, BorderRadius.circular(DonyRadius.card));
  });
}
