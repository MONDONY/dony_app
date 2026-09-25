import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

Widget _harness() => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => DonyBottomSheet.show<void>(
          context,
          title: 'Titre',
          child: const SizedBox(height: 40),
        ),
        child: const Text('ouvrir'),
      ),
    ),
  ),
);

void main() {
  testWidgets('bouton fermer avec le libellé français par défaut', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Fermer'), findsOneWidget);
  });

  testWidgets('bouton fermer traduit en anglais', (tester) async {
    useEnglish();
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close'), findsOneWidget);
    expect(find.byTooltip('Fermer'), findsNothing);
  });
}
