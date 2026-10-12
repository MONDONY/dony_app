import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/flights/data/models/flight_deal.dart';
import 'package:dony/features/flights/data/models/flight_filters.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:dony/features/flights/data/repositories/flights_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum FlightSearchStatus { editing, loading, loaded, error }

class FlightSearchState extends Equatable {
  const FlightSearchState({
    this.query = const FlightSearchQuery(),
    this.status = FlightSearchStatus.editing,
    this.result,
    this.filters = const FlightFilters(),
    this.error,
  });

  final FlightSearchQuery query;
  final FlightSearchStatus status;
  final FlightSearchResult? result;
  final FlightFilters filters;
  final Object? error;

  /// Vrai dès qu'une recherche est lancée ou affichée : l'onglet montre alors
  /// les résultats au lieu du formulaire.
  bool get showsResults => status != FlightSearchStatus.editing;

  List<FlightOffer> get visibleOffers =>
      filters.apply(result?.offers ?? const []);

  FlightFacets get facets => FlightFacets.of(result?.offers ?? const []);

  /// Offre la moins chère et la plus rapide de TOUTES les offres reçues : les
  /// tampons ne bougent pas quand on filtre.
  FlightOffer? get cheapest {
    final offers = result?.offers ?? const <FlightOffer>[];
    if (offers.isEmpty) return null;
    return offers.reduce((a, b) => b.price < a.price ? b : a);
  }

  FlightOffer? get fastest {
    final timed = (result?.offers ?? const <FlightOffer>[])
        .where((o) => o.durationMinutes != null)
        .toList();
    if (timed.isEmpty) return null;
    return timed.reduce(
      (a, b) => b.durationMinutes! < a.durationMinutes! ? b : a,
    );
  }

  FlightSearchState copyWith({
    FlightSearchQuery? query,
    FlightSearchStatus? status,
    FlightSearchResult? result,
    bool clearResult = false,
    FlightFilters? filters,
    Object? error,
  }) => FlightSearchState(
    query: query ?? this.query,
    status: status ?? this.status,
    result: clearResult ? null : (result ?? this.result),
    filters: filters ?? this.filters,
    error: error,
  );

  @override
  List<Object?> get props => [query, status, result, filters, error];
}

/// Formulaire, résultats et filtres de l'onglet Billets.
class FlightSearchCubit extends Cubit<FlightSearchState> {
  FlightSearchCubit(this._repository, this._analytics)
    : super(const FlightSearchState());

  final FlightsRepository _repository;
  final AnalyticsService _analytics;

  /// Préremplit départ et arrivée avec la dernière recherche ou le corridor le
  /// plus récent (`GET /flights/defaults`). Ne remplace jamais une saisie : un
  /// utilisateur plus rapide que le réseau garde ce qu'il a choisi. Un échec
  /// laisse simplement les champs vides.
  Future<void> loadDefaults() async {
    try {
      final defaults = await _repository.defaults();
      final origin = defaults.origin;
      final destination = defaults.destination;
      if (isClosed || origin == null || destination == null) return;
      if (state.query.origin != null || state.query.destination != null) return;
      emit(
        state.copyWith(
          query: state.query.copyWith(origin: origin, destination: destination),
        ),
      );
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.flightsPrefillApplied,
          properties: {'source': defaults.source},
        ),
      );
    } catch (_) {
      // Préremplissage de confort : sans lui, le formulaire reste utilisable.
    }
  }

  void setOrigin(FlightPlace place) =>
      emit(state.copyWith(query: state.query.copyWith(origin: place)));

  void setDestination(FlightPlace place) =>
      emit(state.copyWith(query: state.query.copyWith(destination: place)));

  void swap() => emit(state.copyWith(query: state.query.swapped()));

  /// [returnDate] `null` = aller simple.
  void setDates(FlightWhen? departure, FlightWhen? returnDate) => emit(
    state.copyWith(
      query: FlightSearchQuery(
        origin: state.query.origin,
        destination: state.query.destination,
        departure: departure,
        returnDate: returnDate,
        directOnly: state.query.directOnly,
      ),
    ),
  );

  void setDirectOnly(bool value) =>
      emit(state.copyWith(query: state.query.copyWith(directOnly: value)));

  Future<void> search({bool fromDeal = false}) async {
    final query = state.query;
    if (!query.isComplete) return;
    emit(
      state.copyWith(
        status: FlightSearchStatus.loading,
        clearResult: true,
        filters: const FlightFilters(),
      ),
    );
    try {
      final result = await _repository.search(query);
      if (isClosed) return;
      emit(state.copyWith(status: FlightSearchStatus.loaded, result: result));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.flightsSearchSubmitted,
          properties: {
            'round_trip': query.isRoundTrip,
            'direct_only': query.directOnly,
            'date_mode': _dateMode(query.departure),
            'from_deal': fromDeal,
            'count': result.offers.length,
          },
        ),
      );
    } catch (err) {
      if (isClosed) return;
      final error = unwrapDioError(err);
      emit(state.copyWith(status: FlightSearchStatus.error, error: error));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.flightsSearchFailed,
          properties: {'reason': error.code ?? 'unknown'},
        ),
      );
    }
  }

  /// Un bon plan touché : son trajet et son mois de départ remplissent le
  /// formulaire, puis la recherche part (les autres offres du mois s'affichent).
  Future<void> openDeal(FlightDeal deal, {required bool personalized}) {
    final offer = deal.offer;
    final departure = offer.departureAt;
    emit(
      state.copyWith(
        query: FlightSearchQuery(
          origin: FlightPlace(code: offer.originCode, name: offer.originCode),
          destination: FlightPlace(
            code: offer.destinationCode,
            name: offer.destinationCode,
          ),
          departure: departure == null ? null : FlightWhen.month(departure),
          returnDate: offer.returnAt == null
              ? null
              : FlightWhen.month(offer.returnAt!),
        ),
      ),
    );
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.flightsDealOpened,
        properties: {
          'discount_percent': deal.discountPercent,
          'personalized': personalized,
        },
      ),
    );
    return search(fromDeal: true);
  }

  /// Retour au formulaire depuis les résultats (flèche de l'en-tête).
  void backToForm() => emit(
    state.copyWith(
      status: FlightSearchStatus.editing,
      clearResult: true,
      filters: const FlightFilters(),
    ),
  );

  void applyFilters(FlightFilters filters) {
    emit(state.copyWith(filters: filters));
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.flightsFilterApplied,
        properties: {
          'sort': filters.sort.name,
          'stops': filters.stops.name,
          'airlines_count': filters.airlines.length,
          'gates_count': filters.gates.length,
          'price_range': filters.minPrice != null || filters.maxPrice != null,
        },
      ),
    );
  }

  static String _dateMode(FlightWhen? when) => when == null
      ? 'none'
      : when.wholeMonth
      ? 'month'
      : 'day';
}
