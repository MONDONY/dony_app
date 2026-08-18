import 'package:dony/features/price_grid/bloc/price_grid_event.dart';
import 'package:dony/features/price_grid/bloc/price_grid_state.dart';
import 'package:dony/features/price_grid/data/models/price_grid_item_model.dart';
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

  Future<void> _onLoad(
    PriceGridLoadRequested event,
    Emitter<PriceGridState> emit,
  ) async {
    emit(const PriceGridLoading());
    try {
      final items = await _repository.getItems();
      emit(PriceGridLoaded(items));
    } catch (e) {
      emit(PriceGridError(e.toString()));
    }
  }

  Future<void> _onAdd(
    PriceGridItemAddRequested event,
    Emitter<PriceGridState> emit,
  ) async {
    try {
      emit(const PriceGridLoading());
      await _repository.addItem(
        label: event.label,
        unitPriceNet: event.unitPriceNet,
      );
      final items = await _repository.getItems();
      emit(PriceGridLoaded(items));
    } catch (e) {
      emit(PriceGridError(e.toString()));
    }
  }

  Future<void> _onUpdate(
    PriceGridItemUpdateRequested event,
    Emitter<PriceGridState> emit,
  ) async {
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

  Future<void> _onDelete(
    PriceGridItemDeleteRequested event,
    Emitter<PriceGridState> emit,
  ) async {
    try {
      emit(const PriceGridLoading());
      await _repository.deleteItem(event.itemId);
      final items = await _repository.getItems();
      emit(PriceGridLoaded(items));
    } catch (e) {
      emit(PriceGridError(e.toString()));
    }
  }

  Future<void> _onReorder(
    PriceGridItemsReorderRequested event,
    Emitter<PriceGridState> emit,
  ) async {
    final current = state;
    final previous = current is PriceGridLoaded ? current.items : null;

    // Réordonnancement optimiste. Passer par PriceGridLoading remplacerait la
    // liste par un indicateur de chargement le temps de l'aller-retour : la
    // grille disparaîtrait à chaque déplacement et le mode réorganisation se
    // refermerait. L'ordre s'applique donc dès le lever du doigt.
    if (previous != null) {
      final byId = {for (final item in previous) item.id: item};
      final reordered = <PriceGridItemModel>[
        for (final id in event.orderedIds)
          if (byId.containsKey(id)) byId[id]!,
      ];
      if (reordered.length == previous.length) {
        emit(PriceGridLoaded(reordered));
      }
    }

    try {
      final items = await _repository.reorder(event.orderedIds);
      emit(PriceGridLoaded(items));
    } catch (e) {
      emit(PriceGridError(e.toString()));
      // L'ordre serveur n'a pas changé : on remet la liste telle qu'elle
      // était, après l'état d'erreur qui déclenche le message à l'écran.
      if (previous != null) emit(PriceGridLoaded(previous));
    }
  }
}
