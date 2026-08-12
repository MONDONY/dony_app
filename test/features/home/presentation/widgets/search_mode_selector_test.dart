import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/search_mode_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _trajetsKey = Key('search_mode_segment_trips');
const _colisKey = Key('search_mode_segment_colis');

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

  testWidgets(
    'le libellé sémantique ne duplique pas emoji/texte/compteur (mode trips)',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(SearchModeSelector(
        mode: SearchMode.trips,
        onChanged: (_) {},
        otherModeCount: 8,
      )));

      // Segment actif (Trajets) : pas de compteur, libellé simple.
      expect(
        tester.getSemantics(find.byKey(_trajetsKey)),
        matchesSemantics(
          label: 'Trajets',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );

      // Segment inactif (Colis) avec compteur : le libellé explicite ne
      // doit apparaître qu'une seule fois, sans doublon de l'emoji brut,
      // du texte ou du nombre lus séparément par les enfants.
      expect(
        tester.getSemantics(find.byKey(_colisKey)),
        matchesSemantics(
          label: 'Colis, 8 résultats',
          isButton: true,
          hasSelectedState: true,
        ),
      );

      handle.dispose();
    },
  );

  testWidgets(
    'le compteur est un descendant du segment inactif, pas de l\'actif',
    (tester) async {
      await tester.pumpWidget(wrap(SearchModeSelector(
        mode: SearchMode.trips,
        onChanged: (_) {},
        otherModeCount: 8,
      )));

      // mode trips actif → le compteur doit être posé sur Colis, pas Trajets.
      expect(
        find.descendant(of: find.byKey(_colisKey), matching: find.text('8')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(_trajetsKey), matching: find.text('8')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'chaque segment a une zone tactile d\'au moins 38 points de haut',
    (tester) async {
      await tester.pumpWidget(wrap(SearchModeSelector(
        mode: SearchMode.trips,
        onChanged: (_) {},
      )));

      final trajetsSize = tester.getSize(find.descendant(
        of: find.byKey(_trajetsKey),
        matching: find.byType(GestureDetector),
      ));
      final colisSize = tester.getSize(find.descendant(
        of: find.byKey(_colisKey),
        matching: find.byType(GestureDetector),
      ));

      expect(trajetsSize.height, greaterThanOrEqualTo(38));
      expect(colisSize.height, greaterThanOrEqualTo(38));
    },
  );

  testWidgets(
    'mode parcels : le segment Colis est actif et le compteur se pose sur Trajets',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(SearchModeSelector(
        mode: SearchMode.parcels,
        onChanged: (_) {},
        otherModeCount: 5,
      )));

      expect(
        tester.getSemantics(find.byKey(_colisKey)),
        matchesSemantics(
          label: 'Colis',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_trajetsKey)),
        matchesSemantics(
          label: 'Trajets, 5 résultats',
          isButton: true,
          hasSelectedState: true,
        ),
      );

      expect(
        find.descendant(of: find.byKey(_trajetsKey), matching: find.text('5')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(_colisKey), matching: find.text('5')),
        findsNothing,
      );

      handle.dispose();
    },
  );
}
