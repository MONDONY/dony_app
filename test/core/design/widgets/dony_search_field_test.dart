import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  testWidgets('hint par défaut en français', (tester) async {
    await tester.pumpWidget(_wrap(const DonySearchField()));
    expect(find.text('Rechercher...'), findsOneWidget);
  });

  testWidgets('hint par défaut traduit en anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(_wrap(const DonySearchField()));
    expect(find.text('Search...'), findsOneWidget);
    expect(find.text('Rechercher...'), findsNothing);
  });

  testWidgets('hint explicite l\'emporte sur le défaut', (tester) async {
    await tester.pumpWidget(
      _wrap(const DonySearchField(hint: 'Rechercher un trajet...')),
    );
    expect(find.text('Rechercher un trajet...'), findsOneWidget);
    expect(find.text('Rechercher...'), findsNothing);
  });

  testWidgets('tooltip "Effacer" traduit en anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(_wrap(const DonySearchField()));
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(find.byTooltip('Clear'), findsOneWidget);
  });
}
