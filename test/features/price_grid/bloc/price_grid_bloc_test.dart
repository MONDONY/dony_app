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
      'LoadPriceGrid emits Loading then Loaded',
      build: () {
        when(() => repository.getItems()).thenAnswer((_) async => [_item1, _item2]);
        return PriceGridBloc(repository);
      },
      act: (b) => b.add(const LoadPriceGrid()),
      expect: () => [
        isA<PriceGridLoading>(),
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [_item1, _item2]),
      ],
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'LoadPriceGrid emits Error when repository throws',
      build: () {
        when(() => repository.getItems()).thenThrow(Exception('network error'));
        return PriceGridBloc(repository);
      },
      act: (b) => b.add(const LoadPriceGrid()),
      expect: () => [
        isA<PriceGridLoading>(),
        isA<PriceGridError>(),
      ],
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'AddPriceGridItem calls repo.addItem then reloads',
      build: () {
        when(() => repository.addItem(
              label: any(named: 'label'),
              unitPriceNet: any(named: 'unitPriceNet'),
            )).thenAnswer((_) async => _item1);
        when(() => repository.getItems()).thenAnswer((_) async => [_item1, _item2]);
        return PriceGridBloc(repository);
      },
      act: (b) => b.add(const AddPriceGridItem(label: 'Valise cabine', unitPriceNet: 10.0)),
      expect: () => [
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [_item1, _item2]),
      ],
      verify: (_) => verify(() => repository.addItem(
            label: 'Valise cabine',
            unitPriceNet: 10.0,
          )).called(1),
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'UpdatePriceGridItem calls repo.updateItem then reloads',
      build: () {
        when(() => repository.updateItem(
              itemId: any(named: 'itemId'),
              label: any(named: 'label'),
              unitPriceNet: any(named: 'unitPriceNet'),
            )).thenAnswer((_) async => _item1);
        when(() => repository.getItems()).thenAnswer((_) async => [_item1, _item2]);
        return PriceGridBloc(repository);
      },
      act: (b) => b.add(const UpdatePriceGridItem(
        itemId: 'uuid-1',
        label: 'Valise 23kg',
        unitPriceNet: 20.0,
      )),
      expect: () => [
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [_item1, _item2]),
      ],
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'DeletePriceGridItem calls repo.deleteItem then reloads',
      build: () {
        when(() => repository.deleteItem(any())).thenAnswer((_) async {});
        when(() => repository.getItems()).thenAnswer((_) async => [_item2]);
        return PriceGridBloc(repository);
      },
      act: (b) => b.add(const DeletePriceGridItem('uuid-1')),
      expect: () => [
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [_item2]),
      ],
    );

    blocTest<PriceGridBloc, PriceGridState>(
      'ReorderPriceGridItems calls repo.reorder then reloads',
      build: () {
        when(() => repository.reorder(['uuid-2', 'uuid-1']))
            .thenAnswer((_) async => [_item2, _item1]);
        return PriceGridBloc(repository);
      },
      act: (b) => b.add(const ReorderPriceGridItems(['uuid-2', 'uuid-1'])),
      expect: () => [
        isA<PriceGridLoaded>().having((s) => s.items, 'items', [_item2, _item1]),
      ],
    );
  });
}
