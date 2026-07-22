// Garantit la STABILITÉ du sous-arbre du sélecteur de mode dans la rangée de
// chips. Le compteur de l'autre mode arrive après coup (appel réseau) : si sa
// présence entrait dans la clé du sélecteur, l'arrivée du nombre détruirait le
// widget et le remonterait, ce qui emporterait l'animation de 200 ms du segment
// actif. Comparer les `Element` avant/après est la seule vérification qui
// distingue un rebuild (même Element) d'un remount (Element neuf).

import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/home_filter_chips_row.dart';
import 'package:dony/features/home/presentation/widgets/search_mode_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap({
  required int? otherModeCount,
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
      otherModeCount: otherModeCount,
      activeTrips: activeTrips,
      onModeChanged: (_) {},
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

  testWidgets(
    'le sélecteur de mode n\'est pas remonté quand le compteur apparaît',
    (tester) async {
      await tester.pumpWidget(_wrap(otherModeCount: null));

      final avant = tester.element(find.byType(SearchModeSelector));

      // Même arbre, seul le compteur change : le sélecteur doit être mis à
      // jour en place, pas détruit puis recréé.
      await tester.pumpWidget(_wrap(otherModeCount: 8));

      final apres = tester.element(find.byType(SearchModeSelector));

      expect(
        identical(avant, apres),
        isTrue,
        reason:
            'le sélecteur de mode a été démonté puis remonté à l\'arrivée du '
            'compteur : sa clé encode la présence du nombre, et le segment '
            'actif perd son animation',
      );
    },
  );

  testWidgets('le compteur est bien rendu après le second pump', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(otherModeCount: null));
    expect(find.byKey(const Key('mode-other-count')), findsNothing);

    await tester.pumpWidget(_wrap(otherModeCount: 8));
    expect(find.byKey(const Key('mode-other-count')), findsOneWidget);
  });
}

// Le filtre « Pour mes trajets » doit être atteignable depuis la rangée visible
// sur la carte, pas seulement enfoui dans la feuille de filtres : c'est le
// raccourci le plus utile du mode Colis.
void _matchingMyTripsChipTests() {
  testWidgets('mode Colis : la pastille « Pour mes trajets » est dans la rangée',
      (tester) async {
    await tester.pumpWidget(_wrap(otherModeCount: null));

    expect(find.byKey(const Key('chip-row-matching-my-trips')), findsOneWidget);
    expect(find.text('Pour mes trajets'), findsOneWidget);
  });

  testWidgets('mode Trajets : la pastille est absente', (tester) async {
    await tester.pumpWidget(
      _wrap(otherModeCount: null, mode: SearchMode.trips),
    );

    expect(find.byKey(const Key('chip-row-matching-my-trips')), findsNothing);
  });

  testWidgets('avec des trajets actifs, le tap bascule le filtre',
      (tester) async {
    var bascules = 0;
    var blocages = 0;
    await tester.pumpWidget(_wrap(
      otherModeCount: null,
      activeTrips: 3,
      onMatchingMyTripsToggle: () => bascules++,
      onMatchingMyTripsBlocked: () => blocages++,
    ));

    await tester.tap(find.byKey(const Key('chip-row-matching-my-trips')));
    await tester.pumpAndSettle();

    expect(bascules, 1);
    expect(blocages, 0);
  });

  testWidgets('sans trajet actif connu, le tap explique au lieu de filtrer',
      (tester) async {
    var bascules = 0;
    var blocages = 0;
    await tester.pumpWidget(_wrap(
      otherModeCount: null,
      activeTrips: 0,
      onMatchingMyTripsToggle: () => bascules++,
      onMatchingMyTripsBlocked: () => blocages++,
    ));

    await tester.tap(find.byKey(const Key('chip-row-matching-my-trips')));
    await tester.pumpAndSettle();

    expect(bascules, 0);
    expect(blocages, 1);
  });

  testWidgets('nombre de trajets inconnu : la pastille reste utilisable',
      (tester) async {
    // Résumé d'activité en échec : ne pas griser sur une supposition, le
    // serveur tranchera. Même règle que dans la feuille de filtres.
    var bascules = 0;
    await tester.pumpWidget(_wrap(
      otherModeCount: null,
      activeTrips: null,
      onMatchingMyTripsToggle: () => bascules++,
    ));

    await tester.tap(find.byKey(const Key('chip-row-matching-my-trips')));
    await tester.pumpAndSettle();

    expect(bascules, 1);
  });

  testWidgets('le filtre actif se voit sur la pastille', (tester) async {
    await tester.pumpWidget(_wrap(
      otherModeCount: null,
      filters: const HomeSearchFilters(
        departureCity: 'Paris',
        matchingMyTrips: true,
      ),
    ));

    // La clé est portée par la pastille elle-même, pas par un ancêtre.
    final chip = tester.widget<HomeSmallChip>(
      find.byKey(const Key('chip-row-matching-my-trips')),
    );
    expect(chip.isActive, isTrue);
  });
}
