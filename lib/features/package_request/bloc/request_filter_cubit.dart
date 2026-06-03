import 'package:dony/core/utils/text_search.dart';
import 'package:dony/features/package_request/data/models/package_request.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum RequestQuickFilter { all, open, accepted }

class RequestFilterState extends Equatable {
  final String query;
  final RequestQuickFilter preset;
  const RequestFilterState({this.query = '', this.preset = RequestQuickFilter.all});
  RequestFilterState copyWith({String? query, RequestQuickFilter? preset}) =>
      RequestFilterState(query: query ?? this.query, preset: preset ?? this.preset);
  @override
  List<Object?> get props => [query, preset];
}

bool requestMatchesQuery(PackageRequest r, String query) {
  final q = normalizeSearch(query.trim());
  if (q.isEmpty) {
    return true;
  }
  bool m(String s) => normalizeSearch(s).contains(q);
  return m(r.departureCity) || m(r.arrivalCity) || m(r.contentCategory.label);
}

bool requestMatchesPreset(PackageRequest r, RequestQuickFilter preset) => switch (preset) {
      RequestQuickFilter.all => true,
      RequestQuickFilter.open => r.status == PackageRequestStatus.open ||
          r.status == PackageRequestStatus.negotiating,
      RequestQuickFilter.accepted => r.status == PackageRequestStatus.accepted ||
          r.status == PackageRequestStatus.completed,
    };

List<PackageRequest> applyRequestFilters(List<PackageRequest> all, RequestFilterState f) =>
    all.where((r) => requestMatchesPreset(r, f.preset) && requestMatchesQuery(r, f.query)).toList();

class RequestFilterCubit extends Cubit<RequestFilterState> {
  RequestFilterCubit() : super(const RequestFilterState());
  void setQuery(String q) => emit(state.copyWith(query: q));
  void setPreset(RequestQuickFilter p) => emit(state.copyWith(preset: p));
  void reset() => emit(const RequestFilterState());
}
