import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:dony/features/profile/presentation/widgets/help_tutorial_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

const _tutorial = HelpTutorial(
  id: 'search_intro',
  title: 'Découvrir Yadony',
  description: 'Comprendre la recherche en quelques minutes.',
  youtubeVideoId: 'dQw4w9WgXcQ',
  order: 1,
  active: true,
  contexts: [TutorialContext.search],
  durationLabel: '2:30',
);

Widget _wrap() => MaterialApp(
  home: Scaffold(
    body: HelpTutorialCard(tutorial: _tutorial, onTap: () {}),
  ),
);

void main() {
  testWidgets('affiche le titre, la description et la durée', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Découvrir Yadony'), findsOneWidget);
    expect(
      find.text('Comprendre la recherche en quelques minutes.'),
      findsOneWidget,
    );
    expect(find.text('2:30'), findsOneWidget);
  });

  testWidgets('déclenche onTap au tap sur la carte', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HelpTutorialCard(
            tutorial: _tutorial,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byType(HelpTutorialCard));
    expect(tapped, isTrue);
  });

  testWidgets('anglais : semantics label traduit', (tester) async {
    useEnglish();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Watch the tutorial Découvrir Yadony'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
