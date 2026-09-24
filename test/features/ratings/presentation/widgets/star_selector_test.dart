import 'package:dony/features/ratings/presentation/widgets/star_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('label d\'accessibilité de chaque étoile en français', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(StarSelector(selected: 0, onSelect: (_) {})));

    expect(find.bySemanticsLabel('Noter 1 sur 5'), findsOneWidget);
    expect(find.bySemanticsLabel('Noter 5 sur 5'), findsOneWidget);
  });

  testWidgets('label d\'accessibilité traduit en anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(wrap(StarSelector(selected: 0, onSelect: (_) {})));

    expect(find.bySemanticsLabel('Rate 1 out of 5'), findsOneWidget);
    expect(find.bySemanticsLabel('Rate 5 out of 5'), findsOneWidget);
  });

  testWidgets('tap sur une étoile déclenche onSelect', (tester) async {
    int? selected;
    await tester.pumpWidget(
      wrap(StarSelector(selected: 0, onSelect: (s) => selected = s)),
    );

    await tester.tap(find.bySemanticsLabel('Noter 3 sur 5'));
    expect(selected, 3);
  });
}
