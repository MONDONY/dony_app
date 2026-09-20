// Rangée de chips de filtre de l'écran Rechercher. Le sélecteur de mode n'en
// fait plus partie (il a sa propre ligne, voir `search_mode_selector_test`) :
// la rangée ne porte que des filtres.

import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/home_filter_chips_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({
  SearchMode mode = SearchMode.parcels,
  HomeSearchFilters filters = const HomeSearchFilters(departureCity: 'Paris'),
  int? activeTrips = 2,
  VoidCallback? onMatchingMyTripsToggle,
  VoidCallback? onMatchingMyTripsBlocked,
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
      onKiloProToggle: () {},
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
  group('pastille « Pour mes trajets »', _matchingMyTripsChipTests);
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
