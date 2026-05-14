import 'package:dony/features/favorite_travelers/data/models/favorite_traveler.dart';
import 'package:dony/features/favorite_travelers/data/repositories/favorite_traveler_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'favorite_traveler_event.dart';
part 'favorite_traveler_state.dart';

class FavoriteTravelerBloc
    extends Bloc<FavoriteTravelerEvent, FavoriteTravelerState> {
  final FavoriteTravelerRepository _repository;

  FavoriteTravelerBloc(this._repository)
      : super(const FavoriteTravelerState()) {
    on<FavoriteTravelerLoaded>(_onLoaded);
    on<FavoriteTravelerRemoved>(_onRemoved);
  }

  Future<void> _onLoaded(
    FavoriteTravelerLoaded event,
    Emitter<FavoriteTravelerState> emit,
  ) async {
    emit(state.copyWith(status: FavoriteTravelerStatus.loading));
    try {
      final travelers = await _repository.getAll();
      emit(state.copyWith(
        status: FavoriteTravelerStatus.success,
        travelers: travelers,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: FavoriteTravelerStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onRemoved(
    FavoriteTravelerRemoved event,
    Emitter<FavoriteTravelerState> emit,
  ) async {
    try {
      await _repository.remove(event.travelerId);
      final updatedList =
          state.travelers.where((t) => t.travelerId != event.travelerId).toList();
      emit(state.copyWith(
        status: FavoriteTravelerStatus.success,
        travelers: updatedList,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: FavoriteTravelerStatus.error,
        error: e.toString(),
      ));
    }
  }
}
