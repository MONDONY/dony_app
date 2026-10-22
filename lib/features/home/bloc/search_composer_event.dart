import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:equatable/equatable.dart';

sealed class SearchComposerEvent extends Equatable {
  const SearchComposerEvent();

  @override
  List<Object?> get props => const [];
}

/// Premier comptage à l'ouverture, sur les filtres hérités de l'onglet.
class SearchComposerStarted extends SearchComposerEvent {
  const SearchComposerStarted();
}

/// L'utilisateur règle un filtre au doigt.
class SearchComposerFiltersChanged extends SearchComposerEvent {
  const SearchComposerFiltersChanged(this.filters);

  final HomeSearchFilters filters;

  @override
  List<Object?> get props => [filters];
}

/// « Tout effacer ».
class SearchComposerCleared extends SearchComposerEvent {
  const SearchComposerCleared();
}
