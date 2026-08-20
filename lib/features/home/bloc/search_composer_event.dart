import 'package:dony/features/home/data/models/search_parse_result.dart';
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

/// L'utilisateur valide une phrase, tapée ou dictée.
class SearchComposerPhraseSubmitted extends SearchComposerEvent {
  const SearchComposerPhraseSubmitted(
    this.text, {
    this.fromVoice = false,
    this.voiceDurationMs,
  });

  final String text;
  final bool fromVoice;

  /// Durée de la dictée en millisecondes, mesurée par l'appelant (l'écran,
  /// seul point qui voit l'ouverture et la fermeture de la feuille de
  /// dictée). `null` quand [fromVoice] est `false`, ou si la mesure n'a pas
  /// pu être prise.
  final int? voiceDurationMs;

  @override
  List<Object?> get props => [text, fromVoice, voiceDurationMs];
}

/// L'utilisateur règle un filtre au doigt.
class SearchComposerFiltersChanged extends SearchComposerEvent {
  const SearchComposerFiltersChanged(this.filters);

  final HomeSearchFilters filters;

  @override
  List<Object?> get props => [filters];
}

/// L'utilisateur tranche une ambiguïté que le parseur a refusé de deviner.
class SearchComposerUnresolvedAnswered extends SearchComposerEvent {
  const SearchComposerUnresolvedAnswered({required this.kind, required this.value});

  final UnresolvedKind kind;
  final String value;

  @override
  List<Object?> get props => [kind, value];
}

/// « Tout effacer ».
class SearchComposerCleared extends SearchComposerEvent {
  const SearchComposerCleared();
}
