// État vide de la vue voyageur. La vue entière embarque une GoogleMap, non
// montable en test sans simulateur de plateforme (voir le test ignoré de
// `home_screen_test.dart`) : l'état vide, lui, se monte seul.

import 'package:dony/features/home/presentation/map_traveler_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/l10n_test_helpers.dart';

Widget _wrap({required bool isNearMe}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: MapTravelerEmptyState(isNearMe: isNearMe),
    ),
  ),
);

void main() {
  testWidgets('en français : « Près de moi » garde ses guillemets courbes', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(isNearMe: true));
    // L'entrée animée de l'état vide pose des minuteries : on les laisse
    // expirer avant la fin du test.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Aucune demande dans ce rayon'), findsOneWidget);
    expect(
      find.text('Élargis ta zone ou désactive “Près de moi”'),
      findsOneWidget,
    );
  });

  testWidgets('en anglais : état vide « près de moi »', (tester) async {
    useEnglish();
    await tester.pumpWidget(_wrap(isNearMe: true));
    // L'entrée animée de l'état vide pose des minuteries : on les laisse
    // expirer avant la fin du test.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('No parcel requests within this radius'), findsOneWidget);
    expect(find.text('Widen your area or turn off “Near me”'), findsOneWidget);
  });

  testWidgets('en anglais : état vide sans filtre de position', (tester) async {
    useEnglish();
    await tester.pumpWidget(_wrap(isNearMe: false));
    // L'entrée animée de l'état vide pose des minuteries : on les laisse
    // expirer avant la fin du test.
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('No parcel requests yet'), findsOneWidget);
    expect(
      find.text('Check back soon, new parcel requests are posted every day'),
      findsOneWidget,
    );
  });
}
