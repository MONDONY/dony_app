import 'package:dony/core/utils/text_search.dart';
import 'package:dony/features/package_request/data/models/nego_entry.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum NegoQuickFilter { all, active, terminal }

class NegotiationFilterState extends Equatable {
  final String query;
  final NegoQuickFilter preset;
  const NegotiationFilterState({
    this.query = '',
    this.preset = NegoQuickFilter.all,
  });
  NegotiationFilterState copyWith({String? query, NegoQuickFilter? preset}) =>
      NegotiationFilterState(
        query: query ?? this.query,
        preset: preset ?? this.preset,
      );
  @override
  List<Object?> get props => [query, preset];
}

bool negoMatchesQuery(NegoEntry entry, String query) {
  final q = normalizeSearch(query.trim());
  if (q.isEmpty) {
    return true;
  }
  bool m(String? s) => s != null && normalizeSearch(s).contains(q);
  return m(entry.counterpartyName) ||
      m(entry.departureCity) ||
      m(entry.arrivalCity);
}

// « En cours » / « Terminées » suivent exactement `NegoEntry.isActive` (source
// unique) : un nouveau statut actif (comme AWAITING_COMMISSION côté demande,
// ou un futur statut côté trajet) n'a donc besoin d'être déclaré qu'à un seul
// endroit pour apparaître correctement filtré partout, plutôt que de retomber
// silencieusement dans le mauvais onglet.
bool negoMatchesPreset(NegoEntry entry, NegoQuickFilter preset) =>
    switch (preset) {
      NegoQuickFilter.all => true,
      NegoQuickFilter.active => entry.isActive,
      NegoQuickFilter.terminal => !entry.isActive,
    };

/// Filtre ET trie : les deux sources n'arrivent pas entrelacées, seule une
/// remise en ordre par activité récente donne une liste lisible.
List<NegoEntry> applyNegotiationFilters(
  List<NegoEntry> all,
  NegotiationFilterState f,
) =>
    all
        .where(
          (e) => negoMatchesPreset(e, f.preset) && negoMatchesQuery(e, f.query),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

class NegotiationFilterCubit extends Cubit<NegotiationFilterState> {
  NegotiationFilterCubit() : super(const NegotiationFilterState());
  void setQuery(String q) => emit(state.copyWith(query: q));
  void setPreset(NegoQuickFilter p) => emit(state.copyWith(preset: p));
  void reset() => emit(const NegotiationFilterState());
}
