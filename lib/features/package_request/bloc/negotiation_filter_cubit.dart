import 'package:dony/core/utils/text_search.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum NegoQuickFilter { all, active, terminal }

class NegotiationFilterState extends Equatable {
  final String query;
  final NegoQuickFilter preset;
  const NegotiationFilterState({this.query = '', this.preset = NegoQuickFilter.all});
  NegotiationFilterState copyWith({String? query, NegoQuickFilter? preset}) =>
      NegotiationFilterState(query: query ?? this.query, preset: preset ?? this.preset);
  @override
  List<Object?> get props => [query, preset];
}

bool negoMatchesQuery(NegotiationThread t, String query) {
  final q = normalizeSearch(query.trim());
  if (q.isEmpty) {
    return true;
  }
  bool m(String? s) => s != null && normalizeSearch(s).contains(q);
  return m(t.travelerName) || m(t.departureCity) || m(t.arrivalCity);
}

bool negoMatchesPreset(NegotiationThread t, NegoQuickFilter preset) => switch (preset) {
      NegoQuickFilter.all => true,
      NegoQuickFilter.active => t.status == NegotiationThreadStatus.open ||
          t.status == NegotiationThreadStatus.awaitingTrip ||
          t.status == NegotiationThreadStatus.awaitingPayment,
      NegoQuickFilter.terminal => t.status == NegotiationThreadStatus.accepted ||
          t.status == NegotiationThreadStatus.rejected ||
          t.status == NegotiationThreadStatus.autoRejected ||
          t.status == NegotiationThreadStatus.expired ||
          t.status == NegotiationThreadStatus.cancelled,
    };

List<NegotiationThread> applyNegotiationFilters(
        List<NegotiationThread> all, NegotiationFilterState f) =>
    all.where((t) => negoMatchesPreset(t, f.preset) && negoMatchesQuery(t, f.query)).toList();

class NegotiationFilterCubit extends Cubit<NegotiationFilterState> {
  NegotiationFilterCubit() : super(const NegotiationFilterState());
  void setQuery(String q) => emit(state.copyWith(query: q));
  void setPreset(NegoQuickFilter p) => emit(state.copyWith(preset: p));
  void reset() => emit(const NegotiationFilterState());
}
