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
      'PriceGridItemAddRequested emits Loading then Loaded',
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
      expect: () => [
        isA<PriceGridLoading>(),
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
      'PriceGridItemUpdateRequested emits Loading then Loaded',
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
        isA<PriceGridLoading>(),
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [
          _item1,
          _item2,
        ]),
      ],
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'PriceGridItemDeleteRequested emits Loading then Loaded',
      build: () {
        when(() => repository.deleteItem(any())).thenAnswer((_) async {});
        when(() => repository.getItems()).thenAnswer((_) async => [_item2]);
        return PriceGridBloc(repository);
      },
      act: (b) => b.add(const PriceGridItemDeleteRequested('uuid-1')),
      expect: () => [
        isA<PriceGridLoading>(),
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [_item2]),
      ],
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'PriceGridItemsReorderRequested emits Loading then Loaded',
      build: () {
        when(
          () => repository.reorder(['uuid-2', 'uuid-1']),
        ).thenAnswer((_) async => [_item2, _item1]);
        return PriceGridBloc(repository);
      },
      act: (b) =>
          b.add(const PriceGridItemsReorderRequested(['uuid-2', 'uuid-1'])),
      expect: () => [
        isA<PriceGridLoading>(),
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [
          _item2,
          _item1,
        ]),
      ],
    );
  });
}
