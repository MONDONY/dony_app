import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/home/domain/home_search_filters.dart';
import 'package:equatable/equatable.dart';

class SearchComposerState extends Equatable {
  const SearchComposerState({
    required this.filters,
    this.resultCount,
    this.isCounting = false,
    this.error,
  });

  final HomeSearchFilters filters;

  /// Null tant qu'aucun comptage n'a abouti, ou quand le dernier a échoué.
  /// Le compteur est une aide, jamais un bloquant.
  final int? resultCount;

  final bool isCounting;
  final AppException? error;

  SearchComposerState copyWith({
    HomeSearchFilters? filters,
    int? resultCount,
    bool clearResultCount = false,
    bool? isCounting,
    AppException? error,
    bool clearError = false,
  }) => SearchComposerState(
    filters: filters ?? this.filters,
    resultCount: clearResultCount ? null : (resultCount ?? this.resultCount),
    isCounting: isCounting ?? this.isCounting,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [filters, resultCount, isCounting, error];
}
