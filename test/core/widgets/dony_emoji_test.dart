import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helpers.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

  testWidgets('fr : étiquettes par défaut des raccourcis métier', (
    tester,
  ) async {
    await pump(tester, const DonyEmoji.planeTakeoff());
    expect(tester.widget<Text>(find.byType(Text)).semanticsLabel, 'Décollage');

    await pump(tester, const DonyEmoji.planeLanding());
    expect(
      tester.widget<Text>(find.byType(Text)).semanticsLabel,
      'Atterrissage',
    );

    await pump(tester, const DonyEmoji.parcel());
    expect(tester.widget<Text>(find.byType(Text)).semanticsLabel, 'Colis');
  });

  testWidgets('en : étiquettes par défaut traduites', (tester) async {
    useEnglish();

    await pump(tester, const DonyEmoji.planeTakeoff());
    expect(tester.widget<Text>(find.byType(Text)).semanticsLabel, 'Takeoff');

    await pump(tester, const DonyEmoji.planeLanding());
    expect(tester.widget<Text>(find.byType(Text)).semanticsLabel, 'Landing');

    await pump(tester, const DonyEmoji.parcel());
    expect(tester.widget<Text>(find.byType(Text)).semanticsLabel, 'Parcel');
  });

  testWidgets('un semanticLabel explicite est toujours prioritaire', (
    tester,
  ) async {
    await pump(tester, const DonyEmoji.planeTakeoff(semanticLabel: 'Paris'));
    expect(tester.widget<Text>(find.byType(Text)).semanticsLabel, 'Paris');
  });
}
