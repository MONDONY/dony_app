import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/home/data/models/search_parse_result.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:equatable/equatable.dart';

class SearchComposerState extends Equatable {
  const SearchComposerState({
    required this.filters,
    this.phrase = '',
    this.recognized = const [],
    this.unresolved = const [],
    this.resultCount,
    this.isParsing = false,
    this.isCounting = false,
    this.error,
  });

  final HomeSearchFilters filters;
  final String phrase;
  final List<RecognizedField> recognized;
  final List<UnresolvedItem> unresolved;

  /// Null tant qu'aucun comptage n'a abouti, ou quand le dernier a échoué.
  /// Le compteur est une aide, jamais un bloquant.
  final int? resultCount;

  final bool isParsing;
  final bool isCounting;
  final AppException? error;

  SearchComposerState copyWith({
    HomeSearchFilters? filters,
    String? phrase,
    List<RecognizedField>? recognized,
    List<UnresolvedItem>? unresolved,
    int? resultCount,
    bool clearResultCount = false,
    bool? isParsing,
    bool? isCounting,
    AppException? error,
    bool clearError = false,
  }) =>
      SearchComposerState(
        filters: filters ?? this.filters,
        phrase: phrase ?? this.phrase,
        recognized: recognized ?? this.recognized,
        unresolved: unresolved ?? this.unresolved,
        resultCount: clearResultCount ? null : (resultCount ?? this.resultCount),
        isParsing: isParsing ?? this.isParsing,
        isCounting: isCounting ?? this.isCounting,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [
        filters, phrase, recognized, unresolved,
        resultCount, isParsing, isCounting, error,
      ];
}
