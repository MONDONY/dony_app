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

Widget _wrap({required int? otherModeCount}) => MaterialApp(
  home: Scaffold(
    body: HomeFilterChipsRow(
      mode: SearchMode.parcels,
      filters: const HomeSearchFilters(departureCity: 'Paris'),
      otherModeCount: otherModeCount,
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
    ),
  ),
);

void main() {
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
