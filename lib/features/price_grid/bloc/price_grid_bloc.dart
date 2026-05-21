import 'package:dony/features/price_grid/bloc/price_grid_event.dart';
import 'package:dony/features/price_grid/bloc/price_grid_state.dart';
import 'package:dony/features/price_grid/data/repositories/price_grid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PriceGridBloc extends Bloc<PriceGridEvent, PriceGridState> {
  final PriceGridRepository _repository;

  PriceGridBloc(this._repository) : super(const PriceGridInitial()) {
    on<PriceGridLoadRequested>(_onLoad);
    on<PriceGridItemAddRequested>(_onAdd);
    on<PriceGridItemUpdateRequested>(_onUpdate);
    on<PriceGridItemDeleteRequested>(_onDelete);
    on<PriceGridItemsReorderRequested>(_onReorder);
  }

  Future<void> _onLoad(PriceGridLoadRequested event, Emitter<PriceGridState> emit) async {
    emit(const PriceGridLoading());
    try {
      final items = await _repository.getItems();
      emit(PriceGridLoaded(items));
    } catch (e) {
      emit(PriceGridError(e.toString()));
    }
  }

  Future<void> _onAdd(PriceGridItemAddRequested event, Emitter<PriceGridState> emit) async {
    try {
      emit(const PriceGridLoading());
      await _repository.addItem(label: event.label, unitPriceNet: event.unitPriceNet);
      final items = await _repository.getItems();
      emit(PriceGridLoaded(items));
    } catch (e) {
      emit(PriceGridError(e.toString()));
    }
  }

  Future<void> _onUpdate(PriceGridItemUpdateRequested event, Emitter<PriceGridState> emit) async {
    try {
      emit(const PriceGridLoading());
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

  Future<void> _onDelete(PriceGridItemDeleteRequested event, Emitter<PriceGridState> emit) async {
    try {
      emit(const PriceGridLoading());
      await _repository.deleteItem(event.itemId);
      final items = await _repository.getItems();
      emit(PriceGridLoaded(items));
    } catch (e) {
      emit(PriceGridError(e.toString()));
    }
  }

  Future<void> _onReorder(PriceGridItemsReorderRequested event, Emitter<PriceGridState> emit) async {
    try {
      emit(const PriceGridLoading());
      final items = await _repository.reorder(event.orderedIds);
      emit(PriceGridLoaded(items));
    } catch (e) {
      emit(PriceGridError(e.toString()));
    }
  }
}
