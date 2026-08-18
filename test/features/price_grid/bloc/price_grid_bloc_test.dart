import 'package:bloc_test/bloc_test.dart';
import 'package:dony/features/price_grid/bloc/price_grid_bloc.dart';
import 'package:dony/features/price_grid/bloc/price_grid_event.dart';
import 'package:dony/features/price_grid/bloc/price_grid_state.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPriceGridRepository extends Mock implements PriceGridRepository {}

const _item1 = PriceGridItemModel(
  id: 'uuid-1',
  label: 'Valise cabine',
  unitPriceNet: 10.0,
  unitPriceDisplay: 11.20,
  position: 0,
);

const _item2 = PriceGridItemModel(
  id: 'uuid-2',
  label: 'Sac à dos 50L',
  unitPriceNet: 15.0,
  unitPriceDisplay: 16.80,
  position: 1,
);

// Les mêmes articles tels que le serveur les rend après un réordonnancement :
// mêmes données, positions renumérotées.
const _item2AtTop = PriceGridItemModel(
  id: 'uuid-2',
  label: 'Sac à dos 50L',
  unitPriceNet: 15.0,
  unitPriceDisplay: 16.80,
  position: 0,
);

const _item1AtBottom = PriceGridItemModel(
  id: 'uuid-1',
  label: 'Valise cabine',
  unitPriceNet: 10.0,
  unitPriceDisplay: 11.20,
  position: 1,
);

void main() {
  late MockPriceGridRepository repository;

  setUp(() {
    repository = MockPriceGridRepository();
  });

  group('PriceGridBloc', () {
    test('initial state is PriceGridInitial', () {
      expect(PriceGridBloc(repository).state, isA<PriceGridInitial>());
    });

    blocTest<PriceGridBloc, PriceGridState>(
      'PriceGridLoadRequested emits Loading then Loaded',
      build: () {
        when(
          () => repository.getItems(),
        ).thenAnswer((_) async => [_item1, _item2]);
        return PriceGridBloc(repository);
      },
      act: (b) => b.add(const PriceGridLoadRequested()),
      expect: () => [
        isA<PriceGridLoading>(),
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [
          _item1,
          _item2,
        ]),
      ],
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'PriceGridLoadRequested emits Error when repository throws',
      build: () {
        when(() => repository.getItems()).thenThrow(Exception('network error'));
        return PriceGridBloc(repository);
      },
      act: (b) => b.add(const PriceGridLoadRequested()),
      expect: () => [isA<PriceGridLoading>(), isA<PriceGridError>()],
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'PriceGridItemAddRequested recharge la grille sans état de chargement',
      build: () {
        when(
          () => repository.addItem(
            label: any(named: 'label'),
            unitPriceNet: any(named: 'unitPriceNet'),
          ),
        ).thenAnswer((_) async => _item1);
        when(
          () => repository.getItems(),
        ).thenAnswer((_) async => [_item1, _item2]);
        return PriceGridBloc(repository);
      },
      act: (b) => b.add(
        const PriceGridItemAddRequested(
          label: 'Valise cabine',
          unitPriceNet: 10.0,
        ),
      ),
      // Aucun PriceGridLoading : la grille doit rester à l'écran pendant
      // l'aller-retour, sinon elle disparaît à chaque ajout.
      expect: () => [
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [
          _item1,
          _item2,
        ]),
      ],
      verify: (_) => verify(
        () => repository.addItem(label: 'Valise cabine', unitPriceNet: 10.0),
      ).called(1),
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'PriceGridItemUpdateRequested recharge la grille sans état de chargement',
      build: () {
        when(
          () => repository.updateItem(
            itemId: any(named: 'itemId'),
            label: any(named: 'label'),
            unitPriceNet: any(named: 'unitPriceNet'),
          ),
        ).thenAnswer((_) async => _item1);
        when(
          () => repository.getItems(),
        ).thenAnswer((_) async => [_item1, _item2]);
        return PriceGridBloc(repository);
      },
      act: (b) => b.add(
        const PriceGridItemUpdateRequested(
          itemId: 'uuid-1',
          label: 'Valise 23kg',
          unitPriceNet: 20.0,
        ),
      ),
      expect: () => [
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [
          _item1,
          _item2,
        ]),
      ],
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'PriceGridItemDeleteRequested recharge la grille sans état de chargement',
      build: () {
        when(() => repository.deleteItem(any())).thenAnswer((_) async {});
        when(() => repository.getItems()).thenAnswer((_) async => [_item2]);
        return PriceGridBloc(repository);
      },
      act: (b) => b.add(const PriceGridItemDeleteRequested('uuid-1')),
      expect: () => [
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [_item2]),
      ],
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'une suppression qui échoue rétablit la grille précédente',
      build: () {
        when(() => repository.deleteItem(any())).thenThrow(Exception('réseau'));
        return PriceGridBloc(repository);
      },
      seed: () => const PriceGridLoaded([_item1, _item2]),
      act: (b) => b.add(const PriceGridItemDeleteRequested('uuid-1')),
      expect: () => [
        isA<PriceGridError>(),
        // L'erreur déclenche le message, puis la liste revient telle quelle :
        // le serveur n'a rien supprimé.
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [
          _item1,
          _item2,
        ]),
      ],
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'PriceGridItemsReorderRequested applique l\'ordre avant la réponse '
      'serveur, sans passer par un état de chargement',
      build: () {
        // Le serveur renvoie les articles avec leurs positions renumérotées.
        when(
          () => repository.reorder(['uuid-2', 'uuid-1']),
        ).thenAnswer((_) async => [_item2AtTop, _item1AtBottom]);
        return PriceGridBloc(repository);
      },
      seed: () => const PriceGridLoaded([_item1, _item2]),
      act: (b) =>
          b.add(const PriceGridItemsReorderRequested(['uuid-2', 'uuid-1'])),
      expect: () => [
        // Ordre optimiste, tout de suite : un indicateur de chargement ferait
        // disparaître la grille à chaque déplacement.
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [
          _item2,
          _item1,
        ]),
        // Puis la vérité serveur, positions renumérotées.
        isA<PriceGridLoaded>().having(
          (s) => s.items.map((e) => '${e.id}@${e.position}').toList(),
          'ordre serveur',
          ['uuid-2@0', 'uuid-1@1'],
        ),
      ],
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'PriceGridItemsReorderRequested rétablit l\'ordre initial si le serveur '
      'refuse',
      build: () {
        when(() => repository.reorder(any())).thenThrow(Exception('réseau'));
        return PriceGridBloc(repository);
      },
      seed: () => const PriceGridLoaded([_item1, _item2]),
      act: (b) =>
          b.add(const PriceGridItemsReorderRequested(['uuid-2', 'uuid-1'])),
      expect: () => [
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [
          _item2,
          _item1,
        ]),
        isA<PriceGridError>(),
        // L'erreur déclenche le message, puis la grille reprend l'ordre que
        // le serveur connaît réellement.
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [
          _item1,
          _item2,
        ]),
      ],
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'PriceGridItemsReorderRequested sans grille chargée n\'invente pas '
      'd\'ordre local',
      build: () {
        when(
          () => repository.reorder(['uuid-2', 'uuid-1']),
        ).thenAnswer((_) async => [_item2, _item1]);
        return PriceGridBloc(repository);
      },
      act: (b) =>
          b.add(const PriceGridItemsReorderRequested(['uuid-2', 'uuid-1'])),
      expect: () => [
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [
          _item2,
          _item1,
        ]),
      ],
    );
  });
}
