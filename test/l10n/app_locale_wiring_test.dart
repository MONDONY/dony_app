import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../helpers/l10n_test_helpers.dart';

/// Même configuration que `MaterialApp.router` dans `lib/app/app.dart`.
Widget _app(Locale? manual) => MaterialApp(
  locale: manual,
  localeListResolutionCallback: AppL10n.localeListResolution,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) {
    AppL10n.syncIntl(Localizations.localeOf(context));
    return child!;
  },
  home: Builder(builder: (c) => Text(c.l10n.commonClose)),
);

void main() {
  tearDown(() => Intl.defaultLocale = null);

  testWidgets('anglais coupé : choix manuel en → reste en français', (
    tester,
  ) async {
    await tester.pumpWidget(_app(AppL10n.en));
    expect(find.text('Fermer'), findsOneWidget);
    expect(Intl.defaultLocale, 'fr');
  });

  testWidgets('anglais activé : choix manuel en → anglais', (tester) async {
    enableEnglish();
    await tester.pumpWidget(_app(AppL10n.en));
    expect(find.text('Close'), findsOneWidget);
    expect(Intl.defaultLocale, 'en');
  });

  testWidgets('anglais activé : téléphone en anglais, pas de choix → anglais', (
    tester,
  ) async {
    enableEnglish();
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(_app(null));
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('anglais activé : téléphone en wolof → français', (tester) async {
    enableEnglish();
    tester.platformDispatcher.localesTestValue = const [Locale('wo', 'SN')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(_app(null));
    expect(find.text('Fermer'), findsOneWidget);
  });

  testWidgets(
    'anglais activé : English puis « Langue du téléphone » (fr) → fr partout',
    (tester) async {
      enableEnglish();
      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(_app(AppL10n.en));
      expect(find.text('Close'), findsOneWidget);
      expect(Intl.defaultLocale, 'en');

      await tester.pumpWidget(_app(null));
      await tester.pump();
      expect(find.text('Fermer'), findsOneWidget);
      expect(Intl.defaultLocale, 'fr');
    },
  );

  testWidgets(
    'anglais activé : choix Français, le téléphone passe en en_GB → reste fr',
    (tester) async {
      enableEnglish();
      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(_app(AppL10n.fr));
      expect(Intl.defaultLocale, 'fr');

      tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
      await tester.pump();
      expect(find.text('Fermer'), findsOneWidget);
      expect(Intl.defaultLocale, 'fr');
    },
  );

  testWidgets(
    'anglais activé : choix Français, téléphone en_US qui passe en en_GB → fr',
    (tester) async {
      enableEnglish();
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(_app(AppL10n.fr));
      expect(Intl.defaultLocale, 'fr');

      tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
      await tester.pump();
      expect(find.text('Fermer'), findsOneWidget);
      expect(Intl.defaultLocale, 'fr');
    },
  );
}
