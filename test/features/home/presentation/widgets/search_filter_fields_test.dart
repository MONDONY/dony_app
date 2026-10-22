// Champs de filtre partagés du composeur : libellés en français (inchangés)
// et en anglais.

import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/presentation/widgets/search_filter_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../../helpers/l10n_test_helpers.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Widget _fields() => _wrap(
  Column(
    children: [
      DatePresetsField(
        value: const HomeSearchFilters(departureCity: 'Paris'),
        onChanged: (_) {},
      ),
      PriceField(maxPrice: null, onTap: () {}),
      TransportModeField(mode: null, onTap: () {}),
      WeightField(weightKg: 6, onChanged: (_) {}),
    ],
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  testWidgets('en français : libellés inchangés', (tester) async {
    await tester.pumpWidget(_fields());

    expect(find.text("Aujourd'hui"), findsOneWidget);
    expect(find.text('Cette semaine'), findsOneWidget);
    expect(find.text('Ce mois'), findsOneWidget);
    expect(find.text('PÉRIODE'), findsOneWidget);
    expect(find.text('Choisir'), findsOneWidget);
    expect(find.text('PRIX MAX'), findsOneWidget);
    expect(find.text('Tous'), findsNWidgets(2));
    expect(find.text('POIDS MIN'), findsOneWidget);
  });

  testWidgets('en anglais : libellés traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(_fields());

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('PERIOD'), findsOneWidget);
    expect(find.text('Choose'), findsOneWidget);
    expect(find.text('MAX PRICE'), findsOneWidget);
    expect(find.text('Any'), findsNWidgets(2));
    expect(find.text('MIN WEIGHT'), findsOneWidget);
  });

  testWidgets('en anglais : sélecteur de poids traduit', (tester) async {
    useEnglish();
    await tester.pumpWidget(_fields());

    await tester.tap(find.text('MIN WEIGHT'));
    await tester.pumpAndSettle();

    expect(find.text('Minimum trip weight'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('en anglais : sélecteurs de prix et de transport traduits', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () =>
                    showPricePicker(context, maxPrice: null, onApply: (_) {}),
                child: const Text('prix'),
              ),
              TextButton(
                onPressed: () =>
                    showTransportPicker(context, mode: null, onApply: (_) {}),
                child: const Text('transport'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('prix'));
    await tester.pumpAndSettle();
    expect(find.text('Maximum price'), findsOneWidget);
    expect(find.text('Any price'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
    Navigator.of(tester.element(find.text('Apply'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('transport'));
    await tester.pumpAndSettle();
    expect(find.text('Transport mode'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('DateField sans libellé affiche « DATE »', (tester) async {
    await tester.pumpWidget(_wrap(DateField(date: null, onChanged: (_) {})));

    expect(find.text('DATE'), findsOneWidget);
  });

  testWidgets('le champ de période du composeur s\'appelle « PÉRIODE »', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(SearchPeriodField(start: null, end: null, onChanged: (_) {})),
    );

    expect(find.text('PÉRIODE'), findsOneWidget);
    expect(find.text('DATE'), findsNothing);
  });

  group('champ PÉRIODE : calendrier de période', () {
    const loc = DefaultMaterialLocalizations();

    // Jour à [n] jours d'aujourd'hui, sans `Duration` : un changement d'heure
    // décalerait l'heure de minuit.
    DateTime inDays(int n) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day + n);
    }

    Future<HomeSearchFilters?> pick(
      WidgetTester tester, {
      required HomeSearchFilters value,
      required DateTime start,
      required DateTime end,
    }) async {
      HomeSearchFilters? received;
      await tester.pumpWidget(
        _wrap(DatePresetsField(value: value, onChanged: (f) => received = f)),
      );
      await tester.tap(find.byKey(const Key('search-period-field')));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      // Saisie au clavier : indépendante du jour où tourne le test.
      await tester.tap(find.byTooltip(loc.inputDateModeButtonLabel));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(DateRangePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), loc.formatCompactDate(start));
      await tester.enterText(fields.at(1), loc.formatCompactDate(end));
      await tester.tap(find.text(loc.okButtonLabel));
      await tester.pumpAndSettle();
      return received;
    }

    testWidgets('choisir du … au … pose la période dans les filtres', (
      tester,
    ) async {
      final start = inDays(3);
      final end = inDays(30);

      final f = await pick(
        tester,
        value: const HomeSearchFilters(departureCity: 'Paris'),
        start: start,
        end: end,
      );

      expect(f?.datePreset, DonyDatePreset.custom);
      expect(f?.dateFrom, start);
      expect(f?.dateTo, end);
      expect(f?.departureCity, 'Paris');
    });

    testWidgets('le même jour deux fois = un seul jour', (tester) async {
      final day = inDays(5);

      final f = await pick(
        tester,
        value: const HomeSearchFilters(),
        start: day,
        end: day,
      );

      expect(f?.customDate, day);
      expect(f?.customDateTo, isNull);
      expect(f?.dateTo, day);
    });

    testWidgets('le calendrier s\'ouvre sur la période en cours', (
      tester,
    ) async {
      final today = inDays(0);
      final start = inDays(2);
      final end = inDays(9);
      await tester.pumpWidget(
        _wrap(
          DatePresetsField(
            value: const HomeSearchFilters().withCustomPeriod(start, end),
            onChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('search-period-field')));
      await tester.pumpAndSettle();

      final dialog = tester.widget<DateRangePickerDialog>(
        find.byType(DateRangePickerDialog),
      );
      expect(dialog.initialDateRange, DateTimeRange(start: start, end: end));
      expect(dialog.firstDate, today);
      expect(dialog.lastDate, DateTime(today.year + 2, today.month, today.day));
    });

    testWidgets('refermer le calendrier sans choisir ne change rien', (
      tester,
    ) async {
      final value = const HomeSearchFilters().withCustomPeriod(
        inDays(2),
        inDays(9),
      );
      var calls = 0;
      await tester.pumpWidget(
        _wrap(DatePresetsField(value: value, onChanged: (_) => calls++)),
      );

      await tester.tap(find.byKey(const Key('search-period-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(loc.closeButtonTooltip).last);
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsNothing);
      expect(calls, 0);
    });

    testWidgets('lecteur d\'écran : un bouton « PÉRIODE, valeur »', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final year = DateTime.now().year;
      await tester.pumpWidget(
        _wrap(
          SearchPeriodField(
            start: DateTime(year, 11, 15),
            end: DateTime(year, 12, 15),
            onChanged: (_) {},
          ),
        ),
      );

      expect(
        tester.getSemantics(
          find.bySemanticsLabel('PÉRIODE, 15 nov. → 15 déc.'),
        ),
        matchesSemantics(
          label: 'PÉRIODE, 15 nov. → 15 déc.',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets(
      'grand texte : une période passe sur deux lignes, sans coupure',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SizedBox(
                  width: 220,
                  child: SearchPeriodField(
                    start: DateTime(2026, 12, 20),
                    end: DateTime(2027, 1, 5),
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(
          find.text('20 déc. 2026 → 5 janv. 2027'),
        );
        expect(text.maxLines, 2);
        expect(text.overflow, isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('une période choisie s\'affiche « début → fin »', (
      tester,
    ) async {
      final year = DateTime.now().year;
      await tester.pumpWidget(
        _wrap(
          DatePresetsField(
            value: const HomeSearchFilters().withCustomPeriod(
              DateTime(year, 11, 15),
              DateTime(year, 12, 15),
            ),
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('15 nov. → 15 déc.'), findsOneWidget);
    });
  });

  testWidgets('en anglais : en-tête et valeur de TransportModeField', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(TransportModeField(mode: null, onTap: () {})),
    );

    expect(find.text('TRANSPORT'), findsOneWidget);
    expect(find.text('Any'), findsOneWidget);
  });

  testWidgets(
    'DateField : date choisie fr non-régression (motif d MMM inchangé)',
    (tester) async {
      final date = DateTime(2026, 10, 6, 14, 5);
      await tester.pumpWidget(_wrap(DateField(date: date, onChanged: (_) {})));

      expect(
        find.textContaining(DateFormat('d MMM', 'fr').format(date)),
        findsOneWidget,
      );
    },
  );

  testWidgets('DateField : date choisie en anglais (motif d MMM en)', (
    tester,
  ) async {
    useEnglish();
    final date = DateTime(2026, 10, 6, 14, 5);
    await tester.pumpWidget(_wrap(DateField(date: date, onChanged: (_) {})));

    expect(
      find.textContaining(DateFormat.MMMd('en').format(date)),
      findsOneWidget,
    );
  });

  group('WeightField : curseur au minimum = aucun minimum', () {
    Future<List<double?>> openAndConfirm(
      WidgetTester tester, {
      required double? weightKg,
      Offset? drag,
    }) async {
      final received = <double?>[];
      await tester.pumpWidget(
        _wrap(WeightField(weightKg: weightKg, onChanged: received.add)),
      );
      await tester.tap(find.text('POIDS MIN'));
      await tester.pumpAndSettle();
      if (drag != null) {
        final slider = tester.getRect(find.byType(Slider));
        await tester.dragFrom(Offset(slider.left + 24, slider.center.dy), drag);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();
      return received;
    }

    testWidgets('sans minimum : « Tous », pas de mise en avant', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(WeightField(weightKg: null, onChanged: (_) {})),
      );
      expect(find.text('Tous'), findsOneWidget);
      expect(find.textContaining('kg'), findsNothing);
    });

    testWidgets('confirmer sans toucher : aucun minimum envoyé', (
      tester,
    ) async {
      final received = await openAndConfirm(tester, weightKg: null);
      expect(received, [null]);
    });

    testWidgets('curseur déplacé : le minimum choisi part', (tester) async {
      final received = await openAndConfirm(
        tester,
        weightKg: null,
        drag: const Offset(150, 0),
      );
      expect(received, hasLength(1));
      expect(received.single, isNotNull);
      expect(received.single, greaterThan(kCapacitySliderMinKg));
    });

    testWidgets('minimum hors curseur (60 kg) : ramené à 50, sans planter', (
      tester,
    ) async {
      final received = await openAndConfirm(tester, weightKg: 60);
      expect(received, [kCapacitySliderMaxKg]);
    });
  });
}
