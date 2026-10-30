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

  testWidgets('titleWidget : en-tête, style du titre et croix', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => DonyBottomSheet.show<void>(
                context,
                titleWidget: const Text('Titre vivant'),
                child: const SizedBox(height: 40),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Titre vivant'));
    expect(
      DefaultTextStyle.of(context).style.fontSize,
      Theme.of(context).textTheme.headlineSmall?.fontSize,
    );
    expect(find.byTooltip('Fermer'), findsOneWidget);
  });

  group('footer qui suit des données', () {
    Future<ValueNotifier<bool>> openWithFooter(
      WidgetTester tester, {
      bool initial = true,
    }) async {
      final show = ValueNotifier<bool>(initial);
      addTearDown(show.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => DonyBottomSheet.show<void>(
                  context,
                  title: 'Titre',
                  footer: ValueListenableBuilder<bool>(
                    valueListenable: show,
                    builder: (context, visible, _) => DonyBottomSheetFooter(
                      child: visible
                          ? const SizedBox(key: Key('cta'), height: 52)
                          : null,
                    ),
                  ),
                  child: const SizedBox(key: Key('content'), height: 40),
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      return show;
    }

    Finder frame() => find.byKey(const Key('donyBottomSheetFooter'));

    testWidgets('bouton présent : pied encadré, bouton dedans', (tester) async {
      await openWithFooter(tester);

      expect(
        find.descendant(of: frame(), matching: find.byKey(const Key('cta'))),
        findsOneWidget,
      );
    });

    testWidgets('le bouton disparaît : plus aucun conteneur de pied, la '
        'marge de la zone sûre reste', (tester) async {
      final show = await openWithFooter(tester);
      final contentBottom = tester.getBottomLeft(
        find.byKey(const Key('content')),
      );

      show.value = false;
      await tester.pumpAndSettle();
      expect(frame(), findsNothing);
      expect(find.byKey(const Key('cta')), findsNothing);
      // Le contenu reste au-dessus de la zone sûre (34 dp) : la feuille ne
      // le colle pas au bord de l'écran.
      final screenBottom = tester.getSize(find.byType(MaterialApp)).height;
      final newBottom = tester.getBottomLeft(find.byKey(const Key('content')));
      expect(newBottom.dy, lessThan(screenBottom - 34));
      expect(newBottom.dy, greaterThan(contentBottom.dy));
    });

    testWidgets('le bouton apparaît après l\'ouverture : pied encadré', (
      tester,
    ) async {
      final show = await openWithFooter(tester, initial: false);
      expect(frame(), findsNothing);

      show.value = true;
      await tester.pumpAndSettle();
      expect(frame(), findsOneWidget);
    });

    testWidgets('stickyBottom et footer ensemble : refusés', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const SizedBox()),
      );
      final context = tester.element(find.byType(SizedBox));
      expect(
        () => DonyBottomSheet.show<void>(
          context,
          stickyBottom: const SizedBox(),
          footer: const SizedBox(),
          child: const SizedBox(),
        ),
        throwsAssertionError,
      );
    });
  });

  group('hauteur fixe (heightFraction)', () {
    Widget fixedHarness({bool withFooter = true}) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => DonyBottomSheet.show<void>(
              context,
              title: 'Titre',
              heightFraction: 0.9,
              stickyBottom: withFooter
                  ? const SizedBox(key: Key('cta'), height: 52)
                  : null,
              child: const SizedBox(key: Key('content'), height: 40),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );

    testWidgets('le pied reste collé au bas de la feuille, pas sous le '
        'contenu court', (tester) async {
      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = const Size(720, 1640);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(fixedHarness());
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final content = tester.getRect(find.byKey(const Key('content')));
      final footer = tester.getRect(
        find.byKey(const Key('donyBottomSheetFooter')),
      );
      // Pied au bas de l'écran (feuille ancrée en bas).
      expect(footer.bottom, closeTo(screen.height, 1));
      // Et loin du contenu court : la feuille fait 90 % de la hauteur.
      expect(footer.top - content.bottom, greaterThan(300));
    });

    testWidgets('sans pied : le contenu défile toujours dans la feuille', (
      tester,
    ) async {
      await tester.pumpWidget(fixedHarness(withFooter: false));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('content')), findsOneWidget);
      expect(find.byKey(const Key('donyBottomSheetFooter')), findsNothing);
    });
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
