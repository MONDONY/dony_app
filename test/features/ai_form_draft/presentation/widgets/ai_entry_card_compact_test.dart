import 'package:dony/features/ai_form_draft/data/ai_form_draft_models.dart';
import 'package:dony/features/ai_form_draft/presentation/widgets/ai_entry_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Locale locale,
    double scale = 1.0,
    VoidCallback? onPressed,
  }) async {
    enableEnglish();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: AiEntryCard(
                kind: AiFormKind.trip,
                onPressed: onPressed ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final locale in [AppL10n.fr, AppL10n.en]) {
    testWidgets('compacte (< 80 dp) à 360 dp, bouton 1 ligne : $locale', (
      tester,
    ) async {
      await pump(tester, locale: locale);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AiEntryCard)).height, lessThan(80));
      final btn = find.byKey(const Key('ai-entry-cta'));
      expect(tester.getSize(btn).height, 36);
      final text = tester.widget<Text>(
        find.descendant(of: btn, matching: find.byType(Text)),
      );
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      expect(text.style?.fontSize, isNull);
    });

    testWidgets('texte x1,3 sans overflow, bouton inchangé : $locale', (
      tester,
    ) async {
      await pump(tester, locale: locale, scale: 1.3);
      expect(tester.takeException(), isNull);
      final btn = find.byKey(const Key('ai-entry-cta'));
      expect(tester.getSize(btn).height, lessThanOrEqualTo(48));
    });
  }

  testWidgets('bouton tappable, onPressed appelé', (tester) async {
    var taps = 0;
    await pump(tester, locale: AppL10n.fr, onPressed: () => taps++);
    await tester.tap(find.byKey(const Key('ai-entry-cta')));
    expect(taps, 1);
  });
}
