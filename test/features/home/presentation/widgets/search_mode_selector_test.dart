import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/search_mode_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('affiche les deux segments', (tester) async {
    await tester.pumpWidget(wrap(SearchModeSelector(
      mode: SearchMode.trips,
      onChanged: (_) {},
    )));

    expect(find.text('Trajets'), findsOneWidget);
    expect(find.text('Colis'), findsOneWidget);
  });

  testWidgets('taper sur le segment inactif notifie le nouveau mode', (tester) async {
    SearchMode? recu;
    await tester.pumpWidget(wrap(SearchModeSelector(
      mode: SearchMode.trips,
      onChanged: (m) => recu = m,
    )));

    await tester.tap(find.text('Colis'));
    await tester.pumpAndSettle();

    expect(recu, SearchMode.parcels);
  });

  testWidgets('taper sur le segment déjà actif ne notifie pas', (tester) async {
    var appels = 0;
    await tester.pumpWidget(wrap(SearchModeSelector(
      mode: SearchMode.trips,
      onChanged: (_) => appels++,
    )));

    await tester.tap(find.text('Trajets'));
    await tester.pumpAndSettle();

    expect(appels, 0);
  });

  testWidgets('le compteur est rendu sur le segment inactif', (tester) async {
    await tester.pumpWidget(wrap(SearchModeSelector(
      mode: SearchMode.trips,
      onChanged: (_) {},
      otherModeCount: 8,
    )));

    expect(find.text('8'), findsOneWidget);
  });

  testWidgets('compteur nul ou zéro : rien rendu', (tester) async {
    await tester.pumpWidget(wrap(SearchModeSelector(
      mode: SearchMode.trips,
      onChanged: (_) {},
      otherModeCount: 0,
    )));

    expect(find.text('0'), findsNothing);
  });
}
