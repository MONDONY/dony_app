import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/arrival_range.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../features/matching/presentation/widgets/trip_owner/trip_card_harness.dart';

// Recette du 13/11 : le message de plafond du sélecteur d'arrivée était coupé
// sur une ligne (« Choisissez entre le 25 nov. et le 25 mar… »).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    await loadAppFonts();
  });

  Future<void> open(
    WidgetTester tester, {
    required Locale locale,
    required int maxDays,
    required bool themed,
    TransitionBuilder? builder,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final first = DateTime(2026, 11, 25);
    final last = first.add(Duration(days: maxDays));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDatePicker(
              context: context,
              initialDate: first,
              firstDate: first,
              lastDate: last,
              initialEntryMode: DatePickerEntryMode.input,
              builder: builder ?? (themed ? arrivalPickerBuilder : null),
              errorInvalidText: arrivalOutOfRangeText(
                context.l10n,
                first: first,
                last: last,
                maxDays: maxDays,
                now: DateTime(2026, 11, 13),
              ),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      locale.languageCode == 'fr' ? '26/03/2027' : '03/26/2027',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(locale.languageCode == 'fr' ? 'OK' : 'OK'));
    await tester.pumpAndSettle();
  }

  for (final (locale, maxDays, rule) in [
    (const Locale('fr'), 120, 'au plus 120 jours après le départ'),
    (const Locale('fr'), 14, 'au plus 14 jours après le départ'),
    (const Locale('en'), 120, 'at most 120 days after departure'),
    (const Locale('en'), 14, 'at most 14 days after departure'),
  ]) {
    testWidgets('${locale.languageCode} $maxDays j : règle lisible en entier', (
      tester,
    ) async {
      await open(tester, locale: locale, maxDays: maxDays, themed: true);
      final finder = find.textContaining(rule);
      expect(finder, findsOneWidget);
      final render = tester.renderObject<RenderBox>(finder);
      // Plusieurs lignes, jamais d'ellipse.
      final text = tester.widget<Text>(finder);
      expect(text.maxLines, greaterThan(1));
      // Texte entier sur 3 lignes (18 px chacune), sous le plafond de 5.
      expect(render.size.height, closeTo(54, 1));
      expect(tester.takeException(), isNull);
    });
  }

  // Recette du 13/11 (APK 19:50) : le trajet bateau enveloppait le builder dans
  // un `Theme(Theme.of(ctx).copyWith(colorScheme: …))` qui repartait du thème
  // du dessus et écrasait `errorMaxLines`. La palette passe désormais par le
  // builder lui-même.
  testWidgets('avec la palette de l\'écran : règle toujours lisible', (
    tester,
  ) async {
    await open(
      tester,
      locale: const Locale('fr'),
      maxDays: 120,
      themed: true,
      builder: (ctx, child) => arrivalPickerBuilder(
        ctx,
        child,
        colorScheme: ColorScheme.light(primary: Colors.teal.shade700),
      ),
    );
    final finder = find.textContaining('au plus 120 jours après le départ');
    expect(finder, findsOneWidget);
    final render = tester.renderObject<RenderBox>(finder);
    expect(render.size.height, closeTo(54, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans le builder : message coupé (témoin du défaut)', (
    tester,
  ) async {
    await open(tester, locale: const Locale('fr'), maxDays: 120, themed: false);
    final box = tester.renderObject<RenderBox>(
      find.textContaining('Choisissez entre'),
    );
    // Une seule ligne : c'est le défaut relevé en recette.
    expect(box.size.height, closeTo(18, 1));
  });
}
