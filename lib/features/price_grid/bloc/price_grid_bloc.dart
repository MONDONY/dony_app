import 'package:dony/features/price_grid/bloc/price_grid_event.dart';
import 'package:dony/features/price_grid/bloc/price_grid_state.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PriceGridBloc extends Bloc<PriceGridEvent, PriceGridState> {
  final PriceGridRepository _repository;

  PriceGridBloc(this._repository) : super(PriceGridInitial()) {
    on<LoadPriceGrid>(_onLoad);
    on<AddPriceGridItem>(_onAdd);
    on<UpdatePriceGridItem>(_onUpdate);
    on<DeletePriceGridItem>(_onDelete);
    on<ReorderPriceGridItems>(_onReorder);
  }

  Future<void> _onLoad(LoadPriceGrid event, Emitter<PriceGridState> emit) async {
    emit(PriceGridLoading());
    try {
      final items = await _repository.getItems();
      emit(PriceGridLoaded(items));
    } catch (e) {
      emit(PriceGridError(e.toString()));
    }
  }

  Future<void> _onAdd(AddPriceGridItem event, Emitter<PriceGridState> emit) async {
    try {
      await _repository.addItem(label: event.label, unitPriceNet: event.unitPriceNet);
      final items = await _repository.getItems();
      emit(PriceGridLoaded(items));
    } catch (e) {
      emit(PriceGridError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdatePriceGridItem event, Emitter<PriceGridState> emit) async {
    try {
      await _repository.updateItem(
        itemId: event.itemId,
        label: event.label,
        unitPriceNet: event.unitPriceNet,
      );
      final items = await _repository.getItems();
      emit(PriceGridLoaded(items));
    } catch (e) {
      emit(PriceGridError(e.toString()));
    }
  }

  Future<void> _onDelete(DeletePriceGridItem event, Emitter<PriceGridState> emit) async {
    try {
      await _repository.deleteItem(event.itemId);
      final items = await _repository.getItems();
      emit(PriceGridLoaded(items));
    } catch (e) {
      emit(PriceGridError(e.toString()));
    }
  }

  Future<void> _onReorder(ReorderPriceGridItems event, Emitter<PriceGridState> emit) async {
    try {
      final items = await _repository.reorder(event.orderedIds);
      emit(PriceGridLoaded(items));
    } catch (e) {
      emit(PriceGridError(e.toString()));
    }
  }
}
