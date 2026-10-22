import 'dart:async';
import 'dart:math' as math;

import 'package:bloc/bloc.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:dony/features/package_request/data/models/parcel_size.dart';
import 'package:dony/features/package_request/data/package_request_repository.dart';
import 'package:equatable/equatable.dart';

sealed class PackageRequestSearchEvent extends Equatable {
  const PackageRequestSearchEvent();
  @override
  List<Object?> get props => [];
}

class SearchFiltersChanged extends PackageRequestSearchEvent {
  const SearchFiltersChanged({
    this.departure,
    this.arrival,
    this.dateFrom,
    this.dateTo,
    this.maxWeight,
    this.parcelSize,
    this.userLat,
    this.userLng,
    this.radiusKm,
    this.urgent,
    this.matchingMyTrips,
  });
  final String? departure;
  final String? arrival;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? maxWeight;
  final ParcelSize? parcelSize;
  final double? userLat;
  final double? userLng;
  final double? radiusKm;

  /// Filtre serveur « demandes urgentes » (`urgent=true`) — jamais `false`
  /// envoyé explicitement, seulement présent ou absent côté requête.
  final bool? urgent;

  /// Filtre serveur « demandes compatibles avec mes trajets actifs »
  /// (`matchingMyTrips=true`) — jamais `false` envoyé explicitement, même
  /// convention que [urgent].
  final bool? matchingMyTrips;
  @override
  List<Object?> get props => [
    departure,
    arrival,
    dateFrom,
    dateTo,
    maxWeight,
    parcelSize,
    userLat,
    userLng,
    radiusKm,
    urgent,
    matchingMyTrips,
  ];
}

class SearchLoadMore extends PackageRequestSearchEvent {
  const SearchLoadMore();
}

class SearchRefresh extends PackageRequestSearchEvent {
  const SearchRefresh();
}

enum SearchStatus { initial, loading, loaded, error, loadingMore }

class PackageRequestSearchState extends Equatable {
  const PackageRequestSearchState({
    this.status = SearchStatus.initial,
    this.results = const [],
    this.page = 0,
    this.hasMore = true,
    this.totalElements,
    this.errorMessage,
    this.departure,
    this.arrival,
    this.dateFrom,
    this.dateTo,
    this.maxWeight,
    this.parcelSize,
    this.userLat,
    this.userLng,
    this.radiusKm,
    this.urgent,
    this.matchingMyTrips,
  });

  final SearchStatus status;
  final List<PackageRequestSearchItem> results;
  final int page;
  final bool hasMore;

  /// Total serveur des demandes correspondant aux filtres (toutes pages
  /// confondues). `null` tant qu'aucune page n'est arrivée.
  final int? totalElements;
  final Object? errorMessage;
  final String? departure;
  final String? arrival;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? maxWeight;
  final ParcelSize? parcelSize;
  final double? userLat;
  final double? userLng;
  final double? radiusKm;
  final bool? urgent;
  final bool? matchingMyTrips;

  bool get isNearMeActive => userLat != null && userLng != null;

  /// Nombre de demandes à afficher dans les titres et compteurs.
  ///
  /// Suit le total serveur, pas le nombre de lignes déjà chargées (sinon le
  /// compteur passe de 20 à 40 au fil du défilement). Deux cas gardent le
  /// nombre chargé : un total absent ou plus petit que la liste (un back qui
  /// n'en renvoie pas, lu comme 0), et « près de moi », où le back filtre
  /// APRÈS la pagination : son total peut alors dépasser la liste filtrée.
  int get displayCount {
    if (isNearMeActive) return results.length;
    return math.max(totalElements ?? 0, results.length);
  }

  PackageRequestSearchState copyWith({
    SearchStatus? status,
    List<PackageRequestSearchItem>? results,
    int? page,
    bool? hasMore,
    int? totalElements,
    Object? errorMessage,
    String? departure,
    String? arrival,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? maxWeight,
    ParcelSize? parcelSize,
    double? userLat,
    double? userLng,
    double? radiusKm,
    bool? urgent,
    bool? matchingMyTrips,
  }) => PackageRequestSearchState(
    status: status ?? this.status,
    results: results ?? this.results,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    totalElements: totalElements ?? this.totalElements,
    errorMessage: errorMessage ?? this.errorMessage,
    departure: departure ?? this.departure,
    arrival: arrival ?? this.arrival,
    dateFrom: dateFrom ?? this.dateFrom,
    dateTo: dateTo ?? this.dateTo,
    maxWeight: maxWeight ?? this.maxWeight,
    parcelSize: parcelSize ?? this.parcelSize,
    userLat: userLat ?? this.userLat,
    userLng: userLng ?? this.userLng,
    radiusKm: radiusKm ?? this.radiusKm,
    urgent: urgent ?? this.urgent,
    matchingMyTrips: matchingMyTrips ?? this.matchingMyTrips,
  );

  @override
  List<Object?> get props => [
    status,
    results,
    page,
    hasMore,
    totalElements,
    errorMessage,
    departure,
    arrival,
    dateFrom,
    dateTo,
    maxWeight,
    parcelSize,
    userLat,
    userLng,
    radiusKm,
    urgent,
    matchingMyTrips,
  ];
}

class PackageRequestSearchBloc
    extends Bloc<PackageRequestSearchEvent, PackageRequestSearchState> {
  PackageRequestSearchBloc(this._repository, [this._analytics])
    : super(const PackageRequestSearchState()) {
    on<SearchFiltersChanged>(_onFiltersChanged);
    on<SearchLoadMore>(_onLoadMore);
    on<SearchRefresh>(_onRefresh);
  }

  final PackageRequestRepository _repository;
  final AnalyticsService? _analytics;

  Future<void> _onFiltersChanged(
    SearchFiltersChanged e,
    Emitter<PackageRequestSearchState> emit,
  ) async {
    emit(
      PackageRequestSearchState(
        status: SearchStatus.loading,
        departure: e.departure,
        arrival: e.arrival,
        dateFrom: e.dateFrom,
        dateTo: e.dateTo,
        maxWeight: e.maxWeight,
        parcelSize: e.parcelSize,
        userLat: e.userLat,
        userLng: e.userLng,
        radiusKm: e.radiusKm,
        urgent: e.urgent,
        matchingMyTrips: e.matchingMyTrips,
      ),
    );
    try {
      final page = await _repository.search(
        departure: e.departure,
        arrival: e.arrival,
        dateFrom: e.dateFrom,
        dateTo: e.dateTo,
        maxWeight: e.maxWeight,
        parcelSize: e.parcelSize,
        lat: e.userLat,
        lng: e.userLng,
        radiusKm: e.radiusKm,
        urgent: e.urgent,
        matchingMyTrips: e.matchingMyTrips,
      );
      emit(
        state.copyWith(
          status: SearchStatus.loaded,
          results: page.content,
          page: 0,
          hasMore: page.content.length >= page.size,
          totalElements: page.totalElements,
        ),
      );
      unawaited(
        _analytics?.logEvent(
          AnalyticsEvents.packageRequestSearched,
          properties: {
            if (e.departure != null) 'departure': e.departure!,
            if (e.arrival != null) 'arrival': e.arrival!,
          },
        ),
      );
      // Liste scorée « colis sur mes trajets » : c'est désormais une recherche
      // filtrée, l'event suit le filtre plutôt que l'écran dédié supprimé.
      if (e.matchingMyTrips == true) {
        unawaited(
          _analytics?.logEvent(
            AnalyticsEvents.tripMatchingViewed,
            properties: {'count': page.content.length},
          ),
        );
      }
    } catch (err) {
      emit(
        state.copyWith(
          status: SearchStatus.error,
          errorMessage: unwrapDioError(err),
        ),
      );
    }
  }

  Future<void> _onLoadMore(
    SearchLoadMore e,
    Emitter<PackageRequestSearchState> emit,
  ) async {
    if (state.status != SearchStatus.loaded || !state.hasMore) return;
    emit(state.copyWith(status: SearchStatus.loadingMore));
    try {
      final next = state.page + 1;
      final page = await _repository.search(
        departure: state.departure,
        arrival: state.arrival,
        dateFrom: state.dateFrom,
        dateTo: state.dateTo,
        maxWeight: state.maxWeight,
        parcelSize: state.parcelSize,
        lat: state.userLat,
        lng: state.userLng,
        radiusKm: state.radiusKm,
        urgent: state.urgent,
        matchingMyTrips: state.matchingMyTrips,
        page: next,
      );
      emit(
        state.copyWith(
          status: SearchStatus.loaded,
          results: [...state.results, ...page.content],
          page: next,
          hasMore: page.content.length >= page.size,
          totalElements: page.totalElements,
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(
          status: SearchStatus.error,
          errorMessage: unwrapDioError(err),
        ),
      );
    }
  }

  Future<void> _onRefresh(
    SearchRefresh e,
    Emitter<PackageRequestSearchState> emit,
  ) => _onFiltersChanged(
    SearchFiltersChanged(
      departure: state.departure,
      arrival: state.arrival,
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
      maxWeight: state.maxWeight,
      parcelSize: state.parcelSize,
      userLat: state.userLat,
      userLng: state.userLng,
      radiusKm: state.radiusKm,
      urgent: state.urgent,
      matchingMyTrips: state.matchingMyTrips,
    ),
    emit,
  );
}
