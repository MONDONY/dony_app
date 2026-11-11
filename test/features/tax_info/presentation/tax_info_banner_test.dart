import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/tax_info/presentation/widgets/tax_info_banner.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tax_info_test_helpers.dart';

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = AppL10n.fr,
    VoidCallback? onOpen,
    VoidCallback? onLater,
    double width = 360,
  }) async {
    useNarrowScreen(tester, width: width);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TaxInfoBanner(
              onOpen: onOpen ?? () {},
              onLater: onLater ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('texte, deux actions, rappels aux deux appuis', (tester) async {
    var opened = 0;
    var later = 0;
    await pump(tester, onOpen: () => opened++, onLater: () => later++);

    expect(find.text(fr.taxInfoBannerTitle), findsOneWidget);
    expect(find.text(fr.taxInfoBannerBody), findsOneWidget);
    expect(fr.taxInfoBannerBody, contains('ne bloque rien'));

    await tester.tap(find.byKey(const Key('tax-info-banner-open')));
    expect(opened, 1);
    expect(later, 0);
    await tester.tap(find.byKey(const Key('tax-info-banner-later')));
    expect(later, 1);
  });

  for (final entry in {
    'fr': (AppL10n.fr, fr),
    'en': (AppL10n.en, en),
  }.entries) {
    final (locale, l) = entry.value;
    testWidgets('${entry.key} : libellés sur une ligne à 360 dp, sans '
        'exception, mêmes hauteurs', (tester) async {
      await pump(tester, locale: locale);
      expect(find.text(l.taxInfoBannerAction), findsOneWidget);
      expect(find.text(l.taxInfoLater), findsOneWidget);
      expectOneLineNotShrunk(
        tester,
        find.byKey(const Key('tax-info-banner-open')),
      );
      expectOneLineNotShrunk(
        tester,
        find.byKey(const Key('tax-info-banner-later')),
      );
      expect(
        tester.getSize(find.byKey(const Key('tax-info-banner-open'))).height,
        tester.getSize(find.byKey(const Key('tax-info-banner-later'))).height,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('écran très étroit (320 dp) : pas de débordement', (
    tester,
  ) async {
    await pump(tester, width: 320);
    expect(tester.takeException(), isNull);
  });
}
