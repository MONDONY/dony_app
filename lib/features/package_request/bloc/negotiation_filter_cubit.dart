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

/// Teste une entrée contre une requête **déjà normalisée**.
///
/// La normalisation appartient à l'appelant, et non à ce prédicat : elle coûte
/// une allocation de `String` par caractère (`split('')` + `StringBuffer`) et
/// ne dépend pas de l'entrée. La refaire à chaque ligne, c'est la refaire
/// autant de fois qu'il y a de discussions, à chaque frappe.
bool negoMatchesNormalizedQuery(NegoEntry entry, String normalizedQuery) {
  if (normalizedQuery.isEmpty) {
    return true;
  }
  bool m(String? s) =>
      s != null && normalizeSearch(s).contains(normalizedQuery);
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
///
/// La requête est normalisée une seule fois, ici, et non par entrée : cette
/// liste est reconstruite à chaque frappe, et elle fusionne désormais les deux
/// sources de discussions.
List<NegoEntry> applyNegotiationFilters(
  List<NegoEntry> all,
  NegotiationFilterState f,
) {
  final query = normalizeSearch(f.query.trim());
  return <NegoEntry>[
    for (final e in all)
      if (negoMatchesPreset(e, f.preset) &&
          negoMatchesNormalizedQuery(e, query))
        e,
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

class NegotiationFilterCubit extends Cubit<NegotiationFilterState> {
  NegotiationFilterCubit() : super(const NegotiationFilterState());
  void setQuery(String q) => emit(state.copyWith(query: q));
  void setPreset(NegoQuickFilter p) => emit(state.copyWith(preset: p));
  void reset() => emit(const NegotiationFilterState());
}
