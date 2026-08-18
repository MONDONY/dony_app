import 'package:bloc_test/bloc_test.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/price_grid/bloc/price_grid_bloc.dart';
import 'package:dony/features/price_grid/bloc/price_grid_event.dart';
import 'package:dony/features/price_grid/bloc/price_grid_state.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
import 'package:dony/features/price_grid/presentation/price_grid_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPriceGridBloc extends MockBloc<PriceGridEvent, PriceGridState>
    implements PriceGridBloc {}

const _items = [
  PriceGridItemModel(
    id: 'a1',
    label: 'Téléphone & électronique',
    unitPriceNet: 12.0,
    unitPriceDisplay: 12.60,
    position: 1,
  ),
  PriceGridItemModel(
    id: 'a2',
    label: 'Vêtements & tissus',
    unitPriceNet: 8.0,
    unitPriceDisplay: 8.40,
    position: 2,
  ),
  PriceGridItemModel(
    id: 'a3',
    label: 'Chaussures',
    unitPriceNet: 15.0,
    unitPriceDisplay: 15.75,
    position: 3,
  ),
];

Widget _wrap(PriceGridBloc bloc) {
  return MaterialApp(
    home: BlocProvider<PriceGridBloc>.value(
      value: bloc,
      child: const PriceGridScreen(),
    ),
  );
}

PriceGridBloc _blocWith(PriceGridState state) {
  final bloc = _MockPriceGridBloc();
  whenListen(bloc, const Stream<PriceGridState>.empty(), initialState: state);
  return bloc;
}

void main() {
  setUpAll(() {
    // mocktail exige une valeur de repli pour capturer les events du BLoC.
    registerFallbackValue(const PriceGridLoadRequested());
  });

  group('PriceGridScreen — états', () {
    testWidgets('chargement : indicateur de progression', (tester) async {
      await tester.pumpWidget(_wrap(_blocWith(const PriceGridLoading())));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('erreur : message et bouton Réessayer', (tester) async {
      await tester.pumpWidget(
        _wrap(_blocWith(const PriceGridError('Réseau indisponible'))),
      );
      await tester.pump();

      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Réseau indisponible'), findsOneWidget);
    });

    testWidgets('grille vide : invite à créer une étiquette', (tester) async {
      await tester.pumpWidget(
        _wrap(_blocWith(const PriceGridLoaded([]))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aucune étiquette'), findsOneWidget);
      expect(find.text('Nouvelle étiquette'), findsOneWidget);
      // Le vide dit déjà que le barème vaut pour tous les trajets.
      expect(
        find.textContaining('tous vos trajets'),
        findsOneWidget,
      );
    });
  });

  group('PriceGridScreen — liste', () {
    testWidgets('affiche une étiquette par article', (tester) async {
      await tester.pumpWidget(_wrap(_blocWith(const PriceGridLoaded(_items))));
      await tester.pumpAndSettle();

      expect(find.byType(DonyPriceTag), findsNWidgets(3));
      expect(find.text('Chaussures'), findsOneWidget);
    });

    testWidgets('montre le prix payé et le net encaissé', (tester) async {
      await tester.pumpWidget(_wrap(_blocWith(const PriceGridLoaded(_items))));
      await tester.pumpAndSettle();

      // Le prix payé par l'expéditeur domine, le net est en légende.
      expect(find.textContaining('12,60'), findsOneWidget);
      expect(find.textContaining('vous recevez'), findsNWidgets(3));
    });

    testWidgets('affiche le tampon de portée du barème', (tester) async {
      await tester.pumpWidget(_wrap(_blocWith(const PriceGridLoaded(_items))));
      await tester.pumpAndSettle();

      expect(find.text('Valable sur tous vos trajets'), findsOneWidget);
    });

    testWidgets('rappelle la commission en pied de liste', (tester) async {
      await tester.pumpWidget(_wrap(_blocWith(const PriceGridLoaded(_items))));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Vous encaissez exactement votre montant'),
        findsOneWidget,
      );
    });
  });

  group('PriceGridScreen — réorganisation', () {
    testWidgets('mode normal : menus d\'options, pas de poignées', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_blocWith(const PriceGridLoaded(_items))));
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuButton<String>), findsNWidgets(3));
      expect(find.byType(ReorderableDragStartListener), findsNothing);
      expect(find.text('Réordonner'), findsOneWidget);
    });

    testWidgets('« Réordonner » révèle les poignées et masque les menus', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_blocWith(const PriceGridLoaded(_items))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Réordonner'));
      await tester.pumpAndSettle();

      expect(find.byType(ReorderableDragStartListener), findsNWidgets(3));
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.text('Terminé'), findsOneWidget);
    });

    testWidgets('« Terminé » ramène aux menus d\'options', (tester) async {
      await tester.pumpWidget(_wrap(_blocWith(const PriceGridLoaded(_items))));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Réordonner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terminé'));
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuButton<String>), findsNWidgets(3));
    });

    testWidgets('déplacer une étiquette envoie le nouvel ordre au serveur', (
      tester,
    ) async {
      final bloc = _blocWith(const PriceGridLoaded(_items));
      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Réordonner'));
      await tester.pumpAndSettle();

      // Descendre la première étiquette d'un cran. Le déplacement se fait par
      // petits pas : ReorderableListView réévalue les positions à chaque
      // mouvement, un saut unique ne déclenche aucun réordonnancement.
      final handle = find.byType(ReorderableDragStartListener).first;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      // ReorderableDragStartListener saisit dès le contact, sans appui long.
      await tester.pump(const Duration(milliseconds: 200));
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final captured = verify(() => bloc.add(captureAny())).captured
          .whereType<PriceGridItemsReorderRequested>()
          .toList();

      expect(
        captured,
        isNotEmpty,
        reason: 'le déplacement doit émettre un réordonnancement',
      );
      expect(captured.last.orderedIds.first, 'a2');
      expect(captured.last.orderedIds, containsAll(['a1', 'a2', 'a3']));
    });
  });

  group('PriceGridScreen — suppression', () {
    testWidgets('le dialogue prévient que le retrait vaut pour tous', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_blocWith(const PriceGridLoaded(_items))));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();

      expect(find.text('Supprimer l\'étiquette ?'), findsOneWidget);
      // Le retrait ne vaut pas que pour le trajet en cours : la grille est
      // commune, et le dialogue doit le dire avant de supprimer.
      expect(
        find.textContaining('sera retiré de votre grille, sur tous vos '
            'trajets'),
        findsOneWidget,
      );
    });

    testWidgets('confirmer envoie la suppression', (tester) async {
      final bloc = _blocWith(const PriceGridLoaded(_items));
      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();

      final captured = verify(() => bloc.add(captureAny())).captured
          .whereType<PriceGridItemDeleteRequested>()
          .toList();

      expect(captured, hasLength(1));
      expect(captured.single.itemId, 'a1');
    });

    testWidgets('annuler n\'envoie rien', (tester) async {
      final bloc = _blocWith(const PriceGridLoaded(_items));
      await tester.pumpWidget(_wrap(bloc));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      verifyNever(
        () => bloc.add(any(that: isA<PriceGridItemDeleteRequested>())),
      );
    });
  });
}
