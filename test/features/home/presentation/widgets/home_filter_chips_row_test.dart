// Rangée de chips de filtre de l'écran Rechercher. Le sélecteur de mode n'en
// fait plus partie (il a sa propre ligne, voir `search_mode_selector_test`) :
// la rangée ne porte que des filtres.

import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/home_filter_chips_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../../helpers/l10n_test_helpers.dart';

Widget _wrap({
  SearchMode mode = SearchMode.parcels,
  HomeSearchFilters filters = const HomeSearchFilters(departureCity: 'Paris'),
  int? activeTrips = 2,
  VoidCallback? onMatchingMyTripsToggle,
  VoidCallback? onMatchingMyTripsBlocked,
  VoidCallback? onGpProToggle,
  VoidCallback? onSuitcase23Toggle,
}) => MaterialApp(
  home: Scaffold(
    body: HomeFilterChipsRow(
      mode: mode,
      filters: filters,
      activeTrips: activeTrips,
      onUrgentToggle: () {},
      onDateTap: () {},
      onDateClear: () {},
      onRatingTap: () {},
      onRatingClear: () {},
      onCapacityTap: () {},
      onCapacityClear: () {},
      onPriceTap: () {},
      onPriceClear: () {},
      onGpProToggle: onGpProToggle ?? () {},
      onSuitcase23Toggle: onSuitcase23Toggle ?? () {},
      onMaxWeightTap: () {},
      onMaxWeightClear: () {},
      onParcelSizeTap: () {},
      onParcelSizeClear: () {},
      onMatchingMyTripsToggle: onMatchingMyTripsToggle ?? () {},
      onMatchingMyTripsBlocked: onMatchingMyTripsBlocked ?? () {},
    ),
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
  });

  group('pastille « Pour mes trajets »', _matchingMyTripsChipTests);
  group('traductions', _translationTests);
  group('puce GP Pro', _gpProChipTests);
  group('puce Valise 23 kg', _suitcaseChipTests);
  group('date personnalisée', _customDateChipTests);
  group('puce Capacité', _capacityChipTests);
  group('ordre des puces', _chipOrderTests);
}

void _capacityChipTests() {
  HomeSmallChip chip(WidgetTester tester) =>
      tester.widget<HomeSmallChip>(find.byKey(const Key('chip-capacity')));

  Future<void> pumpWith(WidgetTester tester, HomeSearchFilters f) =>
      tester.pumpWidget(_wrap(mode: SearchMode.trips, filters: f));

  testWidgets('sans borne : « Kilos », inactive', (tester) async {
    await pumpWith(tester, const HomeSearchFilters());
    expect(chip(tester).label, 'Kilos');
    expect(chip(tester).isActive, isFalse);
  });

  testWidgets('minimum seul : « ≥ X kg »', (tester) async {
    await pumpWith(tester, const HomeSearchFilters(weightMin: 10));
    expect(chip(tester).label, '≥ 10 kg');
    expect(chip(tester).isActive, isTrue);
  });

  testWidgets('maximum seul : « ≤ Y kg »', (tester) async {
    await pumpWith(tester, const HomeSearchFilters(weightMax: 20));
    expect(chip(tester).label, '≤ 20 kg');
  });

  testWidgets('deux bornes : « X à Y kg », « X to Y kg » en anglais', (
    tester,
  ) async {
    await pumpWith(
      tester,
      const HomeSearchFilters(weightMin: 5, weightMax: 20),
    );
    expect(chip(tester).label, '5 à 20 kg');

    useEnglish();
    await pumpWith(
      tester,
      const HomeSearchFilters(weightMin: 5, weightMax: 20),
    );
    expect(chip(tester).label, '5 to 20 kg');
  });
}

void _customDateChipTests() {
  testWidgets(
    'puce date personnalisée fr non-régression (motif d MMM inchangé)',
    (tester) async {
      final date = DateTime(2026, 10, 6, 14, 5);
      await tester.pumpWidget(
        _wrap(
          filters: HomeSearchFilters(
            departureCity: 'Paris',
            datePreset: DonyDatePreset.custom,
            customDate: date,
          ),
        ),
      );

      expect(
        find.textContaining(DateFormat('d MMM', 'fr').format(date)),
        findsOneWidget,
      );
    },
  );

  testWidgets('puce date personnalisée en anglais (motif d MMM en)', (
    tester,
  ) async {
    useEnglish();
    final date = DateTime(2026, 10, 6, 14, 5);
    await tester.pumpWidget(
      _wrap(
        filters: HomeSearchFilters(
          departureCity: 'Paris',
          datePreset: DonyDatePreset.custom,
          customDate: date,
        ),
      ),
    );

    expect(
      find.textContaining(DateFormat.MMMd('en').format(date)),
      findsOneWidget,
    );
  });

  testWidgets('puce d\'une période : « début → fin »', (tester) async {
    final year = DateTime.now().year;
    await tester.pumpWidget(
      _wrap(
        filters: const HomeSearchFilters(
          departureCity: 'Paris',
        ).withCustomPeriod(DateTime(year, 11, 15), DateTime(year, 12, 15)),
      ),
    );

    expect(find.text('15 nov. → 15 déc.'), findsOneWidget);
  });

  testWidgets('puce d\'une période en anglais', (tester) async {
    useEnglish();
    final year = DateTime.now().year;
    await tester.pumpWidget(
      _wrap(
        filters: const HomeSearchFilters(
          departureCity: 'Paris',
        ).withCustomPeriod(DateTime(year, 11, 15), DateTime(year, 12, 15)),
      ),
    );

    expect(find.text('Nov 15 → Dec 15'), findsOneWidget);
  });
}

void _translationTests() {
  testWidgets('en français : libellés de la rangée inchangés', (tester) async {
    await tester.pumpWidget(_wrap(mode: SearchMode.trips));

    expect(find.text('Toutes dates'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('Kilos'), findsOneWidget);
    expect(find.text('Prix'), findsOneWidget);
    expect(find.text('🔥 Urgent'), findsOneWidget);
    expect(find.text('GP Pro'), findsOneWidget);
  });

  testWidgets('en anglais : aucune date posée, la puce dit « Any date »', (
    tester,
  ) async {
    useEnglish();
    await tester.pumpWidget(_wrap());

    expect(find.text('Any date'), findsOneWidget);
    expect(find.text('For my trips'), findsOneWidget);
    expect(find.text('Size'), findsOneWidget);
    expect(find.text('Toutes dates'), findsNothing);
  });

  testWidgets('en anglais : puces du mode Trajets', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      _wrap(
        mode: SearchMode.trips,
        filters: const HomeSearchFilters(
          departureCity: 'Paris',
          datePreset: DonyDatePreset.thisMonth,
        ),
      ),
    );

    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Rating'), findsOneWidget);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Price'), findsOneWidget);
  });
}

// Le filtre « Pour mes trajets » doit être atteignable depuis la rangée visible
// sur la carte, pas seulement enfoui dans la feuille de filtres : c'est le
// raccourci le plus utile du mode Colis.
void _matchingMyTripsChipTests() {
  testWidgets(
    'mode Colis : la pastille « Pour mes trajets » est dans la rangée',
    (tester) async {
      await tester.pumpWidget(_wrap());

      expect(
        find.byKey(const Key('chip-row-matching-my-trips')),
        findsOneWidget,
      );
      expect(find.text('Pour mes trajets'), findsOneWidget);
    },
  );

  testWidgets('mode Trajets : la pastille est absente', (tester) async {
    await tester.pumpWidget(_wrap(mode: SearchMode.trips));

    expect(find.byKey(const Key('chip-row-matching-my-trips')), findsNothing);
  });

  testWidgets('avec des trajets actifs, le tap bascule le filtre', (
    tester,
  ) async {
    var bascules = 0;
    var blocages = 0;
    await tester.pumpWidget(
      _wrap(
        activeTrips: 3,
        onMatchingMyTripsToggle: () => bascules++,
        onMatchingMyTripsBlocked: () => blocages++,
      ),
    );

    await tester.tap(find.byKey(const Key('chip-row-matching-my-trips')));
    await tester.pumpAndSettle();

    expect(bascules, 1);
    expect(blocages, 0);
  });

  testWidgets('sans trajet actif connu, le tap explique au lieu de filtrer', (
    tester,
  ) async {
    var bascules = 0;
    var blocages = 0;
    await tester.pumpWidget(
      _wrap(
        activeTrips: 0,
        onMatchingMyTripsToggle: () => bascules++,
        onMatchingMyTripsBlocked: () => blocages++,
      ),
    );

    await tester.tap(find.byKey(const Key('chip-row-matching-my-trips')));
    await tester.pumpAndSettle();

    expect(bascules, 0);
    expect(blocages, 1);
  });

  testWidgets('nombre de trajets inconnu : la pastille reste utilisable', (
    tester,
  ) async {
    // Résumé d'activité en échec : ne pas griser sur une supposition, le
    // serveur tranchera. Même règle que dans la feuille de filtres.
    var bascules = 0;
    await tester.pumpWidget(
      _wrap(activeTrips: null, onMatchingMyTripsToggle: () => bascules++),
    );

    await tester.tap(find.byKey(const Key('chip-row-matching-my-trips')));
    await tester.pumpAndSettle();

    expect(bascules, 1);
  });

  testWidgets('le filtre actif se voit sur la pastille', (tester) async {
    await tester.pumpWidget(
      _wrap(
        filters: const HomeSearchFilters(
          departureCity: 'Paris',
          matchingMyTrips: true,
        ),
      ),
    );

    // La clé est portée par la pastille elle-même, pas par un ancêtre.
    final chip = tester.widget<HomeSmallChip>(
      find.byKey(const Key('chip-row-matching-my-trips')),
    );
    expect(chip.isActive, isTrue);
  });
}

void _gpProChipTests() {
  testWidgets('la puce « GP Pro » bascule le filtre au tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(mode: SearchMode.trips, onGpProToggle: () => taps++),
    );

    // La rangée défile : avec la puce Valise 23 kg, GP Pro sort de l'écran
    // de test de 800 px.
    await tester.ensureVisible(find.text('GP Pro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GP Pro'));

    expect(taps, 1);
  });
}

void _suitcaseChipTests() {
  Widget chipOf(WidgetTester tester) =>
      tester.widget(find.byKey(const Key('chip-suitcase-23')));

  testWidgets('mode Trajets : puce présente, juste après la date', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(mode: SearchMode.trips));

    expect(find.text('🧳 Valise 23 kg'), findsOneWidget);
    final date = tester.getTopLeft(find.byKey(const Key('chip-date')));
    final suitcase = tester.getTopLeft(
      find.byKey(const Key('chip-suitcase-23')),
    );
    final rating = tester.getTopLeft(find.text('Note'));
    expect(suitcase.dx, greaterThan(date.dx));
    expect(suitcase.dx, lessThan(rating.dx));
  });

  testWidgets('mode Colis : pas de puce', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.byKey(const Key('chip-suitcase-23')), findsNothing);
  });

  testWidgets('tap : bascule le filtre', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(mode: SearchMode.trips, onSuitcase23Toggle: () => taps++),
    );

    await tester.tap(find.byKey(const Key('chip-suitcase-23')));
    expect(taps, 1);
  });

  testWidgets('état sélectionné suivi du filtre', (tester) async {
    await tester.pumpWidget(_wrap(mode: SearchMode.trips));
    expect((chipOf(tester) as HomeSmallChip).isActive, isFalse);

    await tester.pumpWidget(
      _wrap(
        mode: SearchMode.trips,
        filters: const HomeSearchFilters(suitcase23Only: true),
      ),
    );
    expect((chipOf(tester) as HomeSmallChip).isActive, isTrue);
    // La Capacité garde sa propre valeur : aucune réglée, puce Kilos neutre.
    expect(find.text('Kilos'), findsOneWidget);
  });

  testWidgets('en anglais : « 🧳 23 kg suitcase »', (tester) async {
    useEnglish();
    await tester.pumpWidget(_wrap(mode: SearchMode.trips));

    expect(find.text('🧳 23 kg suitcase'), findsOneWidget);
  });
}

/// Ordre d'usage mesuré pendant le test du 27/09 au 12/10 : date, poids et
/// urgent en tête, avant les filtres plus rares.
void _chipOrderTests() {
  double left(WidgetTester tester, Finder f) => tester.getTopLeft(f).dx;

  testWidgets('trajets : date, kilos, urgent, puis le reste', (tester) async {
    await tester.pumpWidget(_wrap(mode: SearchMode.trips));

    final date = left(tester, find.byKey(const Key('chip-date')));
    final kilos = left(tester, find.byKey(const Key('chip-capacity')));
    final urgent = left(tester, find.byKey(const Key('chip-urgent')));
    final valise = left(tester, find.byKey(const Key('chip-suitcase-23')));
    final note = left(tester, find.text('Note'));
    final prix = left(tester, find.text('Prix'));

    expect(date, lessThan(kilos));
    expect(kilos, lessThan(urgent));
    expect(urgent, lessThan(valise));
    expect(valise, lessThan(note));
    expect(note, lessThan(prix));
  });

  testWidgets('colis : date, pour mes trajets, poids, urgent, taille', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());

    final date = left(tester, find.byKey(const Key('chip-date')));
    final trajets = left(
      tester,
      find.byKey(const Key('chip-row-matching-my-trips')),
    );
    final poids = left(tester, find.text('Kilos'));
    final urgent = left(tester, find.byKey(const Key('chip-urgent')));
    final taille = left(tester, find.text('Taille'));

    expect(date, lessThan(trajets));
    expect(trajets, lessThan(poids));
    expect(poids, lessThan(urgent));
    expect(urgent, lessThan(taille));
  });

  testWidgets('les puces communes gardent la même clé dans les deux modes', (
    tester,
  ) async {
    for (final mode in SearchMode.values) {
      await tester.pumpWidget(_wrap(mode: mode));
      expect(find.byKey(const Key('chip-date')), findsOneWidget);
      expect(find.byKey(const Key('chip-urgent')), findsOneWidget);
    }
  });
}
