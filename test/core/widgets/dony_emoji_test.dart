import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/l10n_test_helpers.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

  testWidgets('fr : étiquette par défaut du colis', (tester) async {
    await pump(tester, const DonyEmoji.parcel());
    expect(tester.widget<Text>(find.byType(Text)).semanticsLabel, 'Colis');
  });

  testWidgets('en : étiquette par défaut traduite', (tester) async {
    useEnglish();

    await pump(tester, const DonyEmoji.parcel());
    expect(tester.widget<Text>(find.byType(Text)).semanticsLabel, 'Parcel');
  });

  testWidgets('un emoji sans raccourci n\'a pas d\'étiquette par défaut', (
    tester,
  ) async {
    await pump(tester, const DonyEmoji('🚗'));
    expect(tester.widget<Text>(find.byType(Text)).semanticsLabel, isNull);
  });

  testWidgets('un semanticLabel explicite est toujours prioritaire', (
    tester,
  ) async {
    await pump(tester, const DonyEmoji.parcel(semanticLabel: 'Paris'));
    expect(tester.widget<Text>(find.byType(Text)).semanticsLabel, 'Paris');
  });
}
