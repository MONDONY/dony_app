import 'package:dony/features/app_update/presentation/screens/force_update_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  Widget buildWidget() => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ForceUpdateScreen(),
  );

  testWidgets('explique simplement qu\'une mise à jour est nécessaire', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    expect(find.text('Une mise à jour est nécessaire'), findsOneWidget);
    expect(find.textContaining('Yadony'), findsOneWidget);
  });

  testWidgets('propose un bouton accessible et actif pour mettre à jour', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Mettre à jour maintenant'), findsOneWidget);

    final inkWell = tester.widget<InkWell>(
      find.ancestor(
        of: find.text('Mettre à jour maintenant'),
        matching: find.byType(InkWell),
      ),
    );
    expect(inkWell.onTap, isNotNull);

    handle.dispose();
  });

  testWidgets('n\'utilise jamais de tiret cadratin dans ses textes', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('\n');

    expect(texts.contains('—'), isFalse);
  });

  testWidgets('bloque le retour arrière (PopScope canPop: false)', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    await tester.pumpAndSettle();

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
  });

  testWidgets(
    'en : repli sur AppL10n.current avant que la langue ne soit connue '
    '(MaterialApp nue, sans délégués)',
    (tester) async {
      // Cet écran peut s'afficher très tôt (avant le premier build de
      // MaterialApp.localizationsDelegates) : buildWidget() ci-dessus ne
      // fournit aucun délégué, exactement ce cas. context.l10n doit alors
      // retomber sur AppL10n.current plutôt que de planter.
      useEnglish();
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('An update is required'), findsOneWidget);
      expect(find.textContaining('Yadony'), findsOneWidget);
      expect(find.text('Update now'), findsOneWidget);
    },
  );
}
