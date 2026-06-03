import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/services/analytics_events.dart';
import '../../../core/services/analytics_service.dart';
import '../data/models/package_request_search_item.dart';
import '../data/models/parcel_size.dart';
import '../data/package_request_repository.dart';

sealed class PackageRequestSearchEvent extends Equatable {
  const PackageRequestSearchEvent();
  @override
  List<Object?> get props => [];
}

class SearchFiltersChanged extends PackageRequestSearchEvent {
  const SearchFiltersChanged({
    this.departure, this.arrival, this.dateFrom, this.dateTo,
    this.maxWeight, this.parcelSize,
    this.userLat, this.userLng, this.radiusKm,
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
  @override
  List<Object?> get props => [departure, arrival, dateFrom, dateTo, maxWeight, parcelSize, userLat, userLng, radiusKm];
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
  });

  final SearchStatus status;
  final List<PackageRequestSearchItem> results;
  final int page;
  final bool hasMore;
  final String? errorMessage;
  final String? departure;
  final String? arrival;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? maxWeight;
  final ParcelSize? parcelSize;
  final double? userLat;
  final double? userLng;
  final double? radiusKm;

  bool get isNearMeActive => userLat != null && userLng != null;

  PackageRequestSearchState copyWith({
    SearchStatus? status,
    List<PackageRequestSearchItem>? results,
    int? page,
    bool? hasMore,
    String? errorMessage,
    String? departure,
    String? arrival,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? maxWeight,
    ParcelSize? parcelSize,
    double? userLat,
    double? userLng,
    double? radiusKm,
  }) =>
      PackageRequestSearchState(
        status: status ?? this.status,
        results: results ?? this.results,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
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
      );

  @override
  List<Object?> get props => [
        status, results, page, hasMore, errorMessage,
        departure, arrival, dateFrom, dateTo, maxWeight, parcelSize,
        userLat, userLng, radiusKm,
      ];
}

class PackageRequestSearchBloc extends Bloc<PackageRequestSearchEvent, PackageRequestSearchState> {
  PackageRequestSearchBloc(this._repository, [this._analytics])
      : super(const PackageRequestSearchState()) {
    on<SearchFiltersChanged>(_onFiltersChanged);
    on<SearchLoadMore>(_onLoadMore);
    on<SearchRefresh>(_onRefresh);
  }

  final PackageRequestRepository _repository;
  final AnalyticsService? _analytics;

  Future<void> _onFiltersChanged(SearchFiltersChanged e, Emitter<PackageRequestSearchState> emit) async {
    emit(PackageRequestSearchState(
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
    ));
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
        page: 0,
      );
      emit(state.copyWith(
        status: SearchStatus.loaded,
        results: page.content,
        page: 0,
        hasMore: page.content.length >= page.size,
      ));
      unawaited(_analytics?.logEvent(
        AnalyticsEvents.packageRequestSearched,
        properties: {
          if (e.departure != null) 'departure': e.departure!,
          if (e.arrival != null) 'arrival': e.arrival!,
        },
      ));
    } catch (err) {
      emit(state.copyWith(status: SearchStatus.error, errorMessage: err.toString()));
    }
  }

  Future<void> _onLoadMore(SearchLoadMore e, Emitter<PackageRequestSearchState> emit) async {
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
        page: next,
      );
      emit(state.copyWith(
        status: SearchStatus.loaded,
        results: [...state.results, ...page.content],
        page: next,
        hasMore: page.content.length >= page.size,
      ));
    } catch (err) {
      emit(state.copyWith(status: SearchStatus.error, errorMessage: err.toString()));
    }
  }

  Future<void> _onRefresh(SearchRefresh e, Emitter<PackageRequestSearchState> emit) =>
      _onFiltersChanged(SearchFiltersChanged(
        departure: state.departure, arrival: state.arrival,
        dateFrom: state.dateFrom, dateTo: state.dateTo,
        maxWeight: state.maxWeight, parcelSize: state.parcelSize,
        userLat: state.userLat, userLng: state.userLng, radiusKm: state.radiusKm,
      ), emit);
}
