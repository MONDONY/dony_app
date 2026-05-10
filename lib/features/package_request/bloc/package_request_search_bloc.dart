import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../data/models/package_request.dart';
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
  });
  final String? departure;
  final String? arrival;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? maxWeight;
  final ParcelSize? parcelSize;
  @override
  List<Object?> get props => [departure, arrival, dateFrom, dateTo, maxWeight, parcelSize];
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
  });

  final SearchStatus status;
  final List<PackageRequest> results;
  final int page;
  final bool hasMore;
  final String? errorMessage;
  final String? departure;
  final String? arrival;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final double? maxWeight;
  final ParcelSize? parcelSize;

  PackageRequestSearchState copyWith({
    SearchStatus? status,
    List<PackageRequest>? results,
    int? page,
    bool? hasMore,
    String? errorMessage,
    String? departure,
    String? arrival,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? maxWeight,
    ParcelSize? parcelSize,
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
      );

  @override
  List<Object?> get props => [
        status, results, page, hasMore, errorMessage,
        departure, arrival, dateFrom, dateTo, maxWeight, parcelSize,
      ];
}

class PackageRequestSearchBloc extends Bloc<PackageRequestSearchEvent, PackageRequestSearchState> {
  PackageRequestSearchBloc(this._repository) : super(const PackageRequestSearchState()) {
    on<SearchFiltersChanged>(_onFiltersChanged);
    on<SearchLoadMore>(_onLoadMore);
    on<SearchRefresh>(_onRefresh);
  }

  final PackageRequestRepository _repository;

  Future<void> _onFiltersChanged(SearchFiltersChanged e, Emitter<PackageRequestSearchState> emit) async {
    emit(PackageRequestSearchState(
      status: SearchStatus.loading,
      departure: e.departure,
      arrival: e.arrival,
      dateFrom: e.dateFrom,
      dateTo: e.dateTo,
      maxWeight: e.maxWeight,
      parcelSize: e.parcelSize,
    ));
    try {
      final page = await _repository.search(
        departure: e.departure,
        arrival: e.arrival,
        dateFrom: e.dateFrom,
        dateTo: e.dateTo,
        maxWeight: e.maxWeight,
        parcelSize: e.parcelSize,
        page: 0,
      );
      emit(state.copyWith(
        status: SearchStatus.loaded,
        results: page.content,
        page: 0,
        hasMore: page.content.length >= page.size,
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
      ), emit);
}
