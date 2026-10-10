import 'dart:async';

import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Nombre de trajets affichés d'un coup sur « Mes trajets » ; « Afficher plus »
/// en ajoute autant.
const int kMoneyTripsPageSize = 10;

/// État d'affichage de « Mes trajets » (FLUTTER-HV, écran D).
class MoneyTripsViewState {
  const MoneyTripsViewState({
    this.expanded = const {},
    this.visibleCount = kMoneyTripsPageSize,
  });

  /// Clés des trajets dépliés.
  final Set<String> expanded;

  /// Nombre de trajets rendus (chargement progressif).
  final int visibleCount;

  bool isExpanded(String key) => expanded.contains(key);
}

/// Dépliage des cartes trajet et chargement progressif de « Mes trajets ».
/// Les cartes sont fermées par défaut, sauf le trajet ciblé ([focusKey]).
class MoneyTripsCubit extends Cubit<MoneyTripsViewState> {
  MoneyTripsCubit(this._analytics, {String? focusKey})
    : super(MoneyTripsViewState(expanded: {?focusKey}));

  final AnalyticsService _analytics;
  bool _viewTracked = false;

  void toggle(String key) {
    final next = {...state.expanded};
    if (!next.remove(key)) next.add(key);
    emit(MoneyTripsViewState(expanded: next, visibleCount: state.visibleCount));
  }

  void showMore() => emit(
    MoneyTripsViewState(
      expanded: state.expanded,
      visibleCount: state.visibleCount + kMoneyTripsPageSize,
    ),
  );

  /// Écran chargé : une seule fois par ouverture. Aucun montant ni trajet.
  void trackViewed({required int tripCount, required bool filtered}) {
    if (_viewTracked) return;
    _viewTracked = true;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.moneyTripsViewed,
        properties: {'trip_count': tripCount, 'filtered': filtered},
      ),
    );
  }
}
