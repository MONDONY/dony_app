import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:dony/features/city/data/city_repository.dart';
import 'city_search_event.dart';
import 'city_search_state.dart';

class CitySearchBloc extends Bloc<CitySearchEvent, CitySearchState> {
  CitySearchBloc(this._repository) : super(const CitySearchInitial()) {
    on<CitySearchQueryChanged>(
      _onQueryChanged,
      transformer: (events, mapper) =>
          events.debounceTime(const Duration(milliseconds: 300)).switchMap(mapper),
    );
    on<CitySearchCleared>(_onCleared);
  }

  final CityRepository _repository;

  Future<void> _onQueryChanged(
    CitySearchQueryChanged event,
    Emitter<CitySearchState> emit,
  ) async {
    if (event.query.trim().length < 2) {
      emit(const CitySearchInitial());
      return;
    }
    emit(const CitySearchLoading());
    try {
      final cities = await _repository.searchCities(event.query.trim());
      emit(CitySearchLoaded(cities));
    } catch (e) {
      emit(CitySearchError(e.toString()));
    }
  }

  void _onCleared(CitySearchCleared event, Emitter<CitySearchState> emit) {
    emit(const CitySearchInitial());
  }
}
