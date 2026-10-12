import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/repositories/flights_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum FlightPlacesStatus { suggestions, loading, loaded, error }

class FlightPlacesState extends Equatable {
  const FlightPlacesState({
    this.status = FlightPlacesStatus.suggestions,
    this.term = '',
    this.places = FlightPlacesCubit.diasporaCities,
    this.error,
  });

  final FlightPlacesStatus status;
  final String term;
  final List<FlightPlace> places;
  final AppException? error;

  @override
  List<Object?> get props => [status, term, places, error];
}

/// Autocomplétion des villes de la feuille « Ville de départ / d'arrivée ».
/// Champ vide (ou trop court) : les villes de la diaspora, sans appel réseau.
class FlightPlacesCubit extends Cubit<FlightPlacesState> {
  FlightPlacesCubit(
    this._repository, {
    this.debounce = const Duration(milliseconds: 300),
  }) : super(const FlightPlacesState());

  final FlightsRepository _repository;
  final Duration debounce;
  Timer? _timer;
  int _generation = 0;

  /// En dessous, le back ne répond rien : inutile de l'appeler.
  static const minTermLength = 2;

  /// Noms propres de villes, identiques en français et en anglais.
  static const diasporaCities = <FlightPlace>[
    FlightPlace(code: 'PAR', name: 'Paris', countryCode: 'FR'), // i18n-ignore
    FlightPlace(code: 'DKR', name: 'Dakar', countryCode: 'SN'), // i18n-ignore
    FlightPlace(code: 'ABJ', name: 'Abidjan', countryCode: 'CI'), // i18n-ignore
    FlightPlace(code: 'BKO', name: 'Bamako', countryCode: 'ML'), // i18n-ignore
    FlightPlace(code: 'DLA', name: 'Douala', countryCode: 'CM'), // i18n-ignore
    FlightPlace(
      code: 'CMN',
      name: 'Casablanca',
      countryCode: 'MA',
    ), // i18n-ignore
    FlightPlace(code: 'COO', name: 'Cotonou', countryCode: 'BJ'), // i18n-ignore
    FlightPlace(code: 'CKY', name: 'Conakry', countryCode: 'GN'), // i18n-ignore
    FlightPlace(
      code: 'OUA',
      name: 'Ouagadougou',
      countryCode: 'BF',
    ), // i18n-ignore
    FlightPlace(code: 'LYS', name: 'Lyon', countryCode: 'FR'), // i18n-ignore
    FlightPlace(
      code: 'BRU',
      name: 'Bruxelles',
      countryCode: 'BE',
    ), // i18n-ignore
  ];

  void termChanged(String raw) {
    final term = raw.trim();
    _timer?.cancel();
    final generation = ++_generation;
    if (term.length < minTermLength) {
      emit(FlightPlacesState(term: term));
      return;
    }
    emit(
      FlightPlacesState(
        status: FlightPlacesStatus.loading,
        term: term,
        places: state.places,
      ),
    );
    _timer = Timer(debounce, () => _fetch(term, generation));
  }

  Future<void> _fetch(String term, int generation) async {
    try {
      final places = await _repository.places(term);
      // Une frappe plus récente a déjà relancé la recherche : on l'ignore.
      if (isClosed || generation != _generation) return;
      emit(
        FlightPlacesState(
          status: FlightPlacesStatus.loaded,
          term: term,
          places: places,
        ),
      );
    } catch (err) {
      if (isClosed || generation != _generation) return;
      emit(
        FlightPlacesState(
          status: FlightPlacesStatus.error,
          term: term,
          places: const [],
          error: unwrapDioError(err),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
