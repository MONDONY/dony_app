import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/l10n_test_helpers.dart';

void main() {
  tearDown(() => Intl.defaultLocale = null);

  group('AppL10n.resolve — anglais coupé', () {
    test('téléphone en anglais → français', () {
      expect(AppL10n.resolve(const [Locale('en', 'US')]), AppL10n.fr);
    });
  });

  group('AppL10n.resolve — anglais activé', () {
    setUp(() => AppL10n.debugEnglishEnabled = true);
    tearDown(() => AppL10n.debugEnglishEnabled = null);

    test('en_US → en', () {
      expect(AppL10n.resolve(const [Locale('en', 'US')]), AppL10n.en);
    });
    test('en_GB → en', () {
      expect(AppL10n.resolve(const [Locale('en', 'GB')]), AppL10n.en);
    });
    test('fr_FR → fr', () {
      expect(AppL10n.resolve(const [Locale('fr', 'FR')]), AppL10n.fr);
    });
    test('seule la langue principale compte : wo puis en → fr', () {
      expect(
        AppL10n.resolve(const [Locale('wo', 'SN'), Locale('en')]),
        AppL10n.fr,
      );
    });
    test('liste vide ou nulle → fr', () {
      expect(AppL10n.resolve(const []), AppL10n.fr);
      expect(AppL10n.resolve(null), AppL10n.fr);
    });
    test('localeListResolution recopie la langue dans Intl', () {
      final l = AppL10n.localeListResolution(const [
        Locale('en'),
      ], AppLocalizations.supportedLocales);
      expect(l, AppL10n.en);
      expect(Intl.defaultLocale, 'en');
    });
  });

  group('AppL10n.currentLocale', () {
    test('Intl non initialisé → fr', () {
      Intl.defaultLocale = null;
      expect(AppL10n.currentLocale, AppL10n.fr);
      expect(AppL10n.localeName, 'fr');
    });
    test('en_US → en', () {
      Intl.defaultLocale = 'en_US';
      expect(AppL10n.currentLocale, AppL10n.en);
      expect(AppL10n.current.commonClose, 'Close');
    });
  });

  group('context.l10n', () {
    testWidgets('sans délégué → repli sur la locale courante (fr)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: (c) => Text(c.l10n.commonClose))),
      );
      expect(find.text('Fermer'), findsOneWidget);
    });
    testWidgets('délégués montés en anglais → anglais', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          Builder(builder: (c) => Text(c.l10n.commonClose)),
          locale: AppL10n.en,
        ),
      );
      expect(find.text('Close'), findsOneWidget);
    });
  });
}
