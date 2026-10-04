import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

Widget _harness({bool showFeedback = false}) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => DonyBottomSheet.show<void>(
          context,
          title: 'Titre',
          showFeedback: showFeedback,
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

  testWidgets('sans showFeedback : pas de scarabée', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.byType(DonyFeedbackButton), findsNothing);
  });

  group('clavier ouvert (FLUTTER-AM)', () {
    // Petit Android (Redmi 720×1640 @2) : barre de navigation de 48, clavier
    // de 300 qui la recouvre.
    Widget keyboardHarness() => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 24),
          viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
          viewInsets: const EdgeInsets.only(bottom: 300),
        ),
        child: child!,
      ),
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => DonyBottomSheet.show<void>(
              context,
              title: 'Titre',
              stickyBottom: const SizedBox(key: Key('cta'), height: 52),
              child: const SizedBox(height: 40),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );

    testWidgets('le bouton colle au clavier, barre de navigation non '
        'comptée deux fois', (tester) async {
      tester.view.physicalSize = const Size(720, 1640);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(keyboardHarness());
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      final footer = tester.widget<Container>(
        find.byKey(const Key('donyBottomSheetFooter')),
      );
      final padding = footer.padding!.resolve(TextDirection.ltr);
      expect(padding.bottom, 300 + DonySpacing.base);
    });
  });

  testWidgets('showFeedback : scarabée avant la croix de l\'en-tête', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(showFeedback: true));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    final scarabee = find.byType(DonyFeedbackButton);
    expect(scarabee, findsOneWidget);
    expect(
      tester.getCenter(scarabee).dx,
      lessThan(tester.getCenter(find.byTooltip('Fermer')).dx),
    );
  });
}
