import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/flights/data/datasources/flight_locator.dart';
import 'package:dony/features/flights/data/datasources/flight_recent_store.dart';
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
    this.recent = const [],
    this.canLocate = false,
    this.locating = false,
  });

  final FlightPlacesStatus status;
  final String term;
  final List<FlightPlace> places;
  final AppException? error;

  /// Villes des recherches récentes pour le champ en cours (départs ou
  /// destinations), affichées avant toute frappe.
  final List<FlightPlace> recent;

  /// « Utiliser ma position » : la permission est déjà accordée.
  final bool canLocate;
  final bool locating;

  FlightPlacesState _search({
    required FlightPlacesStatus status,
    required String term,
    List<FlightPlace>? places,
    AppException? error,
  }) => FlightPlacesState(
    status: status,
    term: term,
    places: places ?? FlightPlacesCubit.diasporaCities,
    error: error,
    recent: recent,
    canLocate: canLocate,
    locating: locating,
  );

  FlightPlacesState copyWith({
    List<FlightPlace>? recent,
    bool? canLocate,
    bool? locating,
  }) => FlightPlacesState(
    status: status,
    term: term,
    places: places,
    error: error,
    recent: recent ?? this.recent,
    canLocate: canLocate ?? this.canLocate,
    locating: locating ?? this.locating,
  );

  @override
  List<Object?> get props => [
    status,
    term,
    places,
    error,
    recent,
    canLocate,
    locating,
  ];
}

/// Autocomplétion de l'écran « Où allez-vous ? ». Champ vide (ou trop
/// court) : les villes récentes et celles de la diaspora, sans appel réseau.
class FlightPlacesCubit extends Cubit<FlightPlacesState> {
  FlightPlacesCubit(
    this._repository, {
    this.debounce = const Duration(milliseconds: 300),
    FlightRecentStore? recents,
    FlightLocator? locator,
    AnalyticsService? analytics,
  }) : _recents = recents,
       _locator = locator,
       _analytics = analytics,
       super(const FlightPlacesState());

  final FlightsRepository _repository;
  final Duration debounce;
  final FlightRecentStore? _recents;
  final FlightLocator? _locator;
  final AnalyticsService? _analytics;

  /// Villes récentes au plus, par champ.
  static const maxRecent = 3;
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

  /// Prépare le champ [departure] (ville de départ) ou d'arrivée : ses
  /// villes récentes et, pour le départ, la ligne « Utiliser ma position ».
  Future<void> focusField({required bool departure}) async {
    final searches = _recents?.read() ?? const [];
    final seen = <String>{};
    final recent = [
      for (final s in searches)
        if (seen.add((departure ? s.origin : s.destination).code))
          departure ? s.origin : s.destination,
    ].take(maxRecent).toList(growable: false);
    emit(state.copyWith(recent: recent, canLocate: false));
    final locator = _locator;
    if (!departure || locator == null) return;
    final can = await locator.canLocate();
    if (isClosed) return;
    emit(state.copyWith(canLocate: can));
  }

  /// Ville la plus proche du téléphone, `null` si introuvable.
  Future<FlightPlace?> locate() async {
    final locator = _locator;
    if (locator == null || state.locating) return null;
    emit(state.copyWith(locating: true));
    final place = await locator.nearestCity();
    if (isClosed) return place;
    emit(state.copyWith(locating: false));
    final analytics = _analytics;
    if (analytics != null) {
      unawaited(
        analytics.logEvent(
          AnalyticsEvents.flightsLocationUsed,
          properties: {'found': place != null},
        ),
      );
    }
    return place;
  }

  void termChanged(String raw) {
    final term = raw.trim();
    _timer?.cancel();
    final generation = ++_generation;
    if (term.length < minTermLength) {
      emit(state._search(status: FlightPlacesStatus.suggestions, term: term));
      return;
    }
    emit(
      state._search(
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
        state._search(
          status: FlightPlacesStatus.loaded,
          term: term,
          places: places,
        ),
      );
    } catch (err) {
      if (isClosed || generation != _generation) return;
      emit(
        state._search(
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
