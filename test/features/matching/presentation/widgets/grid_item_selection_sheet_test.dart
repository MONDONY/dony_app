import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/presentation/widgets/grid_item_selection_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

const _items = [
  AnnouncementGridItemModel(
    id: 'item-1',
    label: 'Téléphone',
    unitPriceNet: 10.0,
    unitPriceDisplay: 11.20,
  ),
  AnnouncementGridItemModel(
    id: 'item-2',
    label: 'Valise cabine',
    unitPriceNet: 20.0,
    unitPriceDisplay: 22.40,
  ),
];

void main() {
  group('GridItemSelectionSheet', () {
    testWidgets('affiche tous les articles passés en paramètre', (tester) async {
      await tester.pumpWidget(_wrap(Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => GridItemSelectionSheet.show(
            context,
            items: _items,
            initialQuantities: {},
            corridor: 'Paris → Dakar',
          ),
          child: const Text('Ouvrir'),
        );
      })));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Téléphone'), findsOneWidget);
      expect(find.text('Valise cabine'), findsOneWidget);
    });

    testWidgets('bouton Confirmer désactivé si aucune quantité', (tester) async {
      await tester.pumpWidget(_wrap(Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => GridItemSelectionSheet.show(
            context,
            items: _items,
            initialQuantities: {},
            corridor: 'Paris → Dakar',
          ),
          child: const Text('Ouvrir'),
        );
      })));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      final confirmKey = find.byKey(const Key('grid-sheet-confirm'));
      expect(confirmKey, findsOneWidget);
      final btn = tester.widget<DonyButton>(confirmKey);
      expect(btn.onPressed, isNull);
    });

    testWidgets('bouton Confirmer activé après incrémentation', (tester) async {
      await tester.pumpWidget(_wrap(Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => GridItemSelectionSheet.show(
            context,
            items: _items,
            initialQuantities: {},
            corridor: 'Paris → Dakar',
          ),
          child: const Text('Ouvrir'),
        );
      })));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('grid-item-add-item-1')));
      await tester.pump();
      final btn = tester.widget<DonyButton>(
          find.byKey(const Key('grid-sheet-confirm')));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('initialQuantities pré-remplit les quantités', (tester) async {
      await tester.pumpWidget(_wrap(Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => GridItemSelectionSheet.show(
            context,
            items: _items,
            initialQuantities: {'item-1': 2},
            corridor: 'Paris → Dakar',
          ),
          child: const Text('Ouvrir'),
        );
      })));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('confirmer retourne les quantités sélectionnées', (tester) async {
      Map<String, int>? returned;
      await tester.pumpWidget(_wrap(Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () async {
            returned = await GridItemSelectionSheet.show(
              context,
              items: _items,
              initialQuantities: {},
              corridor: 'Paris → Dakar',
            );
          },
          child: const Text('Ouvrir'),
        );
      })));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('grid-item-add-item-1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('grid-item-add-item-1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('grid-sheet-confirm')));
      await tester.pumpAndSettle();
      expect(returned, equals({'item-1': 2}));
    });

    testWidgets('décrémentation retire l\'article si quantité atteint 0',
        (tester) async {
      await tester.pumpWidget(_wrap(Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => GridItemSelectionSheet.show(
            context,
            items: _items,
            initialQuantities: {'item-1': 1},
            corridor: 'Paris → Dakar',
          ),
          child: const Text('Ouvrir'),
        );
      })));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      // La quantité initiale 1 doit être affichée
      expect(find.text('1'), findsOneWidget);
      // Décrémenter pour passer à 0 (retire l'entrée)
      await tester.tap(find.byKey(const Key('grid-item-remove-item-1')));
      await tester.pump();
      // Le bouton Confirmer doit repasser à désactivé
      final btn = tester.widget<DonyButton>(
          find.byKey(const Key('grid-sheet-confirm')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('affiche le corridor en sous-titre', (tester) async {
      await tester.pumpWidget(_wrap(Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => GridItemSelectionSheet.show(
            context,
            items: _items,
            initialQuantities: {},
            corridor: 'Paris → Abidjan',
          ),
          child: const Text('Ouvrir'),
        );
      })));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Paris → Abidjan'), findsOneWidget);
    });

    testWidgets('affiche le compteur total après sélection', (tester) async {
      await tester.pumpWidget(_wrap(Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () => GridItemSelectionSheet.show(
            context,
            items: _items,
            initialQuantities: {},
            corridor: 'Paris → Dakar',
          ),
          child: const Text('Ouvrir'),
        );
      })));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('grid-item-add-item-1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('grid-item-add-item-2')));
      await tester.pump();
      expect(find.text('2 articles sélectionnés'), findsOneWidget);
    });
  });
}
