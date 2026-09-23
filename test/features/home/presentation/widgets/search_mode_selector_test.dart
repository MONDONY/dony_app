import 'package:dony/features/home/domain/search_mode.dart';
import 'package:dony/features/home/presentation/widgets/search_mode_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/l10n_test_helpers.dart';

const _trajetsKey = Key('search_mode_segment_trips');
const _colisKey = Key('search_mode_segment_colis');
const _compteurKey = Key('mode-other-count');

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  testWidgets(
    'les deux segments nomment l\'intention et ce que la liste montre',
    (tester) async {
      await tester.pumpWidget(
        wrap(SearchModeSelector(mode: SearchMode.trips, onChanged: (_) {})),
      );

      expect(find.text('J\'envoie un colis'), findsOneWidget);
      expect(find.text('Voyageurs disponibles'), findsOneWidget);
      expect(find.text('Je voyage'), findsOneWidget);
      expect(find.text('Colis à transporter'), findsOneWidget);
    },
  );

  testWidgets('taper sur le segment inactif notifie le nouveau mode', (
    tester,
  ) async {
    SearchMode? recu;
    await tester.pumpWidget(
      wrap(
        SearchModeSelector(mode: SearchMode.trips, onChanged: (m) => recu = m),
      ),
    );

    await tester.tap(find.byKey(_colisKey));
    await tester.pumpAndSettle();

    expect(recu, SearchMode.parcels);
  });

  testWidgets('taper sur le segment déjà actif ne notifie pas', (tester) async {
    var appels = 0;
    await tester.pumpWidget(
      wrap(
        SearchModeSelector(mode: SearchMode.trips, onChanged: (_) => appels++),
      ),
    );

    await tester.tap(find.byKey(_trajetsKey));
    await tester.pumpAndSettle();

    expect(appels, 0);
  });

  testWidgets(
    'le compteur s\'inscrit dans le sous-titre du segment inactif seulement',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          SearchModeSelector(
            mode: SearchMode.trips,
            onChanged: (_) {},
            otherModeCount: 8,
          ),
        ),
      );

      expect(find.text('8 colis à transporter'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_colisKey),
          matching: find.byKey(_compteurKey),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_trajetsKey),
          matching: find.byKey(_compteurKey),
        ),
        findsNothing,
      );
      // Le segment actif garde son sous-titre sans nombre.
      expect(find.text('Voyageurs disponibles'), findsOneWidget);
    },
  );

  testWidgets('compteur nul ou zéro : sous-titre sans nombre, sans clé', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SearchModeSelector(
          mode: SearchMode.trips,
          onChanged: (_) {},
          otherModeCount: 0,
        ),
      ),
    );

    expect(find.byKey(_compteurKey), findsNothing);
    expect(find.text('Colis à transporter'), findsOneWidget);
    expect(find.textContaining('0 colis'), findsNothing);
  });

  testWidgets('un seul résultat de l\'autre côté : accord au singulier', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SearchModeSelector(
          mode: SearchMode.parcels,
          onChanged: (_) {},
          otherModeCount: 1,
        ),
      ),
    );

    expect(find.text('1 voyageur disponible'), findsOneWidget);
  });

  testWidgets(
    'le libellé sémantique porte l\'intention et le sous-titre, sans doublon',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          SearchModeSelector(
            mode: SearchMode.trips,
            onChanged: (_) {},
            otherModeCount: 8,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byKey(_trajetsKey)),
        matchesSemantics(
          label: 'J\'envoie un colis, Voyageurs disponibles',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_colisKey)),
        matchesSemantics(
          label: 'Je voyage, 8 colis à transporter',
          isButton: true,
          hasSelectedState: true,
        ),
      );

      handle.dispose();
    },
  );

  testWidgets(
    'chaque segment a une zone tactile d\'au moins 44 points de haut',
    (tester) async {
      await tester.pumpWidget(
        wrap(SearchModeSelector(mode: SearchMode.trips, onChanged: (_) {})),
      );

      for (final key in [_trajetsKey, _colisKey]) {
        final size = tester.getSize(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(GestureDetector),
          ),
        );
        expect(size.height, greaterThanOrEqualTo(44));
      }
    },
  );

  testWidgets(
    'mode parcels : « Je voyage » est actif et le compteur se pose sur l\'autre segment',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          SearchModeSelector(
            mode: SearchMode.parcels,
            onChanged: (_) {},
            otherModeCount: 5,
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byKey(_colisKey)),
        matchesSemantics(
          label: 'Je voyage, Colis à transporter',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(_trajetsKey)),
        matchesSemantics(
          label: 'J\'envoie un colis, 5 voyageurs disponibles',
          isButton: true,
          hasSelectedState: true,
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(_trajetsKey),
          matching: find.byKey(_compteurKey),
        ),
        findsOneWidget,
      );

      handle.dispose();
    },
  );

  testWidgets('le sélecteur prend toute la largeur disponible', (tester) async {
    await tester.pumpWidget(
      wrap(SearchModeSelector(mode: SearchMode.trips, onChanged: (_) {})),
    );

    final largeur = tester.getSize(find.byType(SearchModeSelector)).width;
    final ecran = tester.getSize(find.byType(Scaffold)).width;
    expect(largeur, ecran - 32);
  });

  testWidgets('en anglais : intentions et compteur traduits', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      wrap(
        SearchModeSelector(
          mode: SearchMode.parcels,
          onChanged: (_) {},
          otherModeCount: 2,
        ),
      ),
    );

    expect(find.text("I'm sending a parcel"), findsOneWidget);
    expect(find.text("I'm traveling"), findsOneWidget);
    expect(find.text('2 travelers available'), findsOneWidget);
    expect(find.text('Parcels to carry'), findsOneWidget);
  });

  testWidgets('en anglais : compteur de colis au singulier', (tester) async {
    useEnglish();
    await tester.pumpWidget(
      wrap(
        SearchModeSelector(
          mode: SearchMode.trips,
          onChanged: (_) {},
          otherModeCount: 1,
        ),
      ),
    );

    expect(find.text('1 parcel to carry'), findsOneWidget);
    expect(find.text('Travelers available'), findsOneWidget);
  });
}
