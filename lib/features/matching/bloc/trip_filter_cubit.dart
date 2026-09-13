import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Filtre statut de la liste « Mes trajets » (chips type Airbnb).
enum TripStatusFilter { all, draft, active, completed, cancelled }

/// Filtre demandé par l'URL (`/announcements/trips?filter=completed`). Une
/// valeur inconnue n'a pas d'effet plutôt que de casser la route.
TripStatusFilter resolveTripFilter(String? value) =>
    TripStatusFilter.values.asNameMap()[value] ?? TripStatusFilter.all;

const _activeStatuses = {'ACTIVE', 'FULL', 'IN_PROGRESS'};

class TripFilterState extends Equatable {
  final TripStatusFilter filter;
  final String query;

  const TripFilterState({this.filter = TripStatusFilter.all, this.query = ''});

  bool matchesStatus(String status) => switch (filter) {
    TripStatusFilter.all => true,
    TripStatusFilter.draft => status == 'DRAFT',
    TripStatusFilter.active => _activeStatuses.contains(status),
    TripStatusFilter.completed => status == 'COMPLETED',
    TripStatusFilter.cancelled => status == 'CANCELLED',
  };

  bool matchesQuery(String departureCity, String arrivalCity) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return true;
    }
    return departureCity.toLowerCase().contains(q) ||
        arrivalCity.toLowerCase().contains(q);
  }

  TripFilterState copyWith({TripStatusFilter? filter, String? query}) =>
      TripFilterState(
        filter: filter ?? this.filter,
        query: query ?? this.query,
      );

  @override
  List<Object?> get props => [filter, query];
}

class TripFilterCubit extends Cubit<TripFilterState> {
  TripFilterCubit(this._analytics) : super(const TripFilterState());

  final AnalyticsService _analytics;

  void setFilter(TripStatusFilter filter) {
    emit(state.copyWith(filter: filter));
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tripFilterApplied,
        properties: {'status': filter.name},
      ),
    );
  }

  void setQuery(String query) => emit(state.copyWith(query: query));

  /// Filtre posé à l'arrivée sur l'écran, sans événement analytics : ce n'est
  /// pas un choix de l'utilisateur, c'est l'appelant qui l'a fixé.
  void seedFilter(TripStatusFilter filter) =>
      emit(state.copyWith(filter: filter));
}
