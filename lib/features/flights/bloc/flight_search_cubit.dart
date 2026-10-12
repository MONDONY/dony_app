import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/flights/data/datasources/flight_recent_store.dart';
import 'package:dony/features/flights/data/models/flight_deal.dart';
import 'package:dony/features/flights/data/models/flight_filters.dart';
import 'package:dony/features/flights/data/models/flight_offer.dart';
import 'package:dony/features/flights/data/models/flight_place.dart';
import 'package:dony/features/flights/data/models/flight_recent_search.dart';
import 'package:dony/features/flights/data/models/flight_search_query.dart';
import 'package:dony/features/flights/data/models/flight_search_result.dart';
import 'package:dony/features/flights/data/repositories/flights_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum FlightSearchStatus { editing, loading, loaded, error }

/// Sortie proposée par l'écran « Aucun vol » (propriété `kind` de
/// `flights_empty_suggestion_tapped`).
enum FlightEmptySuggestion { paris, wholeMonth, aviasales, alert }

class FlightSearchState extends Equatable {
  const FlightSearchState({
    this.query = const FlightSearchQuery(),
    this.status = FlightSearchStatus.editing,
    this.result,
    this.filters = const FlightFilters(),
    this.tab = FlightResultsTab.cheapest,
    this.recents = const [],
    this.error,
  });

  final FlightSearchQuery query;
  final FlightSearchStatus status;
  final FlightSearchResult? result;
  final FlightFilters filters;
  final FlightResultsTab tab;

  /// Recherches récentes gardées sur le téléphone (« Vos recherches »).
  final List<FlightRecentSearch> recents;
  final Object? error;

  /// Vrai dès qu'une recherche est lancée ou affichée : l'onglet montre alors
  /// les résultats au lieu du formulaire.
  bool get showsResults => status != FlightSearchStatus.editing;

  /// Offres qui passent les filtres de la feuille, dans l'ordre du prix.
  List<FlightOffer> get filteredOffers =>
      filters.copyWith(sort: FlightSort.cheapest).apply(result?.offers ?? []);

  /// Meilleure offre de chaque onglet, calculée sur les offres filtrées : les
  /// onglets suivent les filtres.
  Map<FlightResultsTab, FlightTabSummary> get tabSummaries =>
      FlightTabSummary.of(filteredOffers);

  /// Onglet réellement appliqué : « Direct » sans vol direct retombe sur
  /// « Le moins cher » plutôt que d'afficher une liste vide.
  FlightResultsTab get effectiveTab =>
      tabSummaries.containsKey(tab) ? tab : FlightResultsTab.cheapest;

  List<FlightOffer> get visibleOffers =>
      FlightTabSummary.rank(filteredOffers, effectiveTab);

  /// Offre la moins chère de TOUTES les offres reçues (seuil proposé de
  /// l'alerte prix).
  FlightOffer? get cheapest {
    final offers = result?.offers ?? const <FlightOffer>[];
    if (offers.isEmpty) return null;
    return offers.reduce((a, b) => b.price < a.price ? b : a);
  }

  /// Offre la plus rapide de toutes les offres reçues.
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
    FlightResultsTab? tab,
    List<FlightRecentSearch>? recents,
    Object? error,
  }) => FlightSearchState(
    query: query ?? this.query,
    status: status ?? this.status,
    result: clearResult ? null : (result ?? this.result),
    filters: filters ?? this.filters,
    tab: tab ?? this.tab,
    recents: recents ?? this.recents,
    error: error,
  );

  @override
  List<Object?> get props => [
    query,
    status,
    result,
    filters,
    tab,
    recents,
    error,
  ];
}

/// Formulaire, résultats, onglets de tri, filtres et historique de l'onglet
/// Billets.
class FlightSearchCubit extends Cubit<FlightSearchState> {
  FlightSearchCubit(
    this._repository,
    this._analytics, {
    FlightRecentStore? recents,
    DateTime Function()? clock,
  }) : _recents = recents ?? MemoryFlightRecentStore(),
       _clock = clock ?? DateTime.now,
       super(const FlightSearchState()) {
    emit(state.copyWith(recents: _recents.read()));
  }

  final FlightsRepository _repository;
  final AnalyticsService _analytics;
  final FlightRecentStore _recents;
  final DateTime Function() _clock;

  /// Ville proposée en repli quand un trajet ne donne rien depuis une autre
  /// ville de départ (« Paris, mêmes dates »).
  static const paris = FlightPlace(
    code: 'PAR',
    name: 'Paris',
    countryCode: 'FR',
  ); // i18n-ignore

  /// Incrémenté à chaque recherche et au retour au formulaire : une réponse
  /// arrivée après coup (recherche plus récente, flèche retour) est ignorée.
  int _generation = 0;

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

  /// Départ et arrivée choisis ensemble sur l'écran de choix des villes.
  void setRoute({FlightPlace? origin, FlightPlace? destination}) => emit(
    state.copyWith(
      query: state.query.copyWith(origin: origin, destination: destination),
    ),
  );

  void swap() => emit(state.copyWith(query: state.query.swapped()));

  /// Sélecteur « Aller-retour / Aller simple » du formulaire. Passer en aller
  /// simple oublie la date du retour.
  void setRoundTrip(bool roundTrip) => emit(
    state.copyWith(
      query: state.query.copyWith(
        roundTrip: roundTrip,
        clearReturn: !roundTrip,
      ),
    ),
  );

  /// [returnDate] `null` = pas de date de retour (aller simple, ou retour
  /// encore à choisir).
  void setDates(FlightWhen? departure, FlightWhen? returnDate) => emit(
    state.copyWith(
      query: FlightSearchQuery(
        origin: state.query.origin,
        destination: state.query.destination,
        departure: departure,
        returnDate: returnDate,
        directOnly: state.query.directOnly,
        roundTrip: state.query.roundTrip || returnDate != null,
      ),
    ),
  );

  void setDirectOnly(bool value) =>
      emit(state.copyWith(query: state.query.copyWith(directOnly: value)));

  Future<void> search({bool fromDeal = false}) async {
    final query = state.query;
    if (!query.isComplete) return;
    final generation = ++_generation;
    emit(
      state.copyWith(
        status: FlightSearchStatus.loading,
        clearResult: true,
        filters: const FlightFilters(),
        tab: FlightResultsTab.cheapest,
      ),
    );
    try {
      final result = await _repository.search(query);
      if (isClosed || generation != _generation) return;
      final recents = await _remember(query, result);
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          status: FlightSearchStatus.loaded,
          result: result,
          recents: recents,
        ),
      );
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
      if (isClosed || generation != _generation) return;
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

  /// Mémorise la recherche avec son prix le plus bas. Un historique
  /// inaccessible n'empêche jamais d'afficher les résultats.
  Future<List<FlightRecentSearch>> _remember(
    FlightSearchQuery query,
    FlightSearchResult result,
  ) async {
    final lowest = result.offers.isEmpty
        ? null
        : result.offers.map((o) => o.price).reduce((a, b) => a < b ? a : b);
    try {
      return await _recents.add(
        FlightRecentSearch.fromQuery(
          query,
          lowestPrice: lowest,
          currency: result.currency,
          at: _clock(),
        ),
      );
    } catch (_) {
      return state.recents;
    }
  }

  /// Une recherche de « Vos recherches » touchée : elle remplit le
  /// formulaire et repart.
  Future<void> openRecent(FlightRecentSearch recent) {
    final index = state.recents.indexOf(recent);
    emit(state.copyWith(query: recent.toQuery()));
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.flightsRecentSearchOpened,
        properties: {
          'position': index,
          'age_days': _clock().difference(recent.searchedAt).inDays,
        },
      ),
    );
    return search();
  }

  Future<void> clearRecents() async {
    await _recents.clear();
    if (isClosed) return;
    emit(state.copyWith(recents: const []));
    unawaited(
      _analytics.logEvent(AnalyticsEvents.flightsRecentSearchesCleared),
    );
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

  /// « Paris, mêmes dates » de l'écran « Aucun vol ».
  Future<void> searchFromParis() {
    trackSuggestion(FlightEmptySuggestion.paris);
    emit(state.copyWith(query: state.query.copyWith(origin: paris)));
    return search();
  }

  /// « Tout {mois} » de l'écran « Aucun vol » : les jours précis deviennent
  /// leurs mois entiers.
  Future<void> searchWholeMonth() {
    trackSuggestion(FlightEmptySuggestion.wholeMonth);
    final q = state.query;
    FlightWhen? month(FlightWhen? w) =>
        w == null ? null : FlightWhen.month(w.date);
    emit(
      state.copyWith(
        query: FlightSearchQuery(
          origin: q.origin,
          destination: q.destination,
          departure: month(q.departure),
          returnDate: month(q.returnDate),
          directOnly: q.directOnly,
          roundTrip: q.roundTrip,
        ),
      ),
    );
    return search();
  }

  void trackSuggestion(FlightEmptySuggestion kind) => unawaited(
    _analytics.logEvent(
      AnalyticsEvents.flightsEmptySuggestionTapped,
      properties: {'kind': kind.name},
    ),
  );

  /// Retour au formulaire depuis les résultats (flèche ou pastille résumé).
  void backToForm() {
    _generation++;
    emit(
      state.copyWith(
        status: FlightSearchStatus.editing,
        clearResult: true,
        filters: const FlightFilters(),
        tab: FlightResultsTab.cheapest,
      ),
    );
  }

  /// Onglet « Le moins cher / Le plus rapide / Direct » des résultats.
  void selectTab(FlightResultsTab tab) {
    if (tab == state.tab) return;
    emit(state.copyWith(tab: tab));
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.flightsSortTabChanged,
        properties: {'tab': tab.name},
      ),
    );
  }

  void applyFilters(FlightFilters filters) {
    emit(state.copyWith(filters: filters));
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.flightsFilterApplied,
        properties: {
          'sort': state.effectiveTab.name,
          'stops': filters.stops.name,
          'airlines_count': filters.airlines.length,
          'gates_count': filters.gates.length,
          'price_range': filters.minPrice != null || filters.maxPrice != null,
          'slots_count': filters.slots.length,
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
