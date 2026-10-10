import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/payments/money/bloc/money_schedule.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/data/repositories/money_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'money_overview_event.dart';
part 'money_overview_state.dart';

/// Écran « Mon argent », écran « Mes trajets » et pastille d'en-tête
/// (FLUTTER-HV). Ne suit que l'argent des colis : le solde du portefeuille
/// Yadony n'est jamais lu ici (il reste sur `/payments/wallet`).
///
/// Sur un back sans l'aperçu (antérieur à yadony-back #481), l'état chargé
/// est vide avec `upcomingAvailable: false` : l'écran annonce une arrivée
/// prochaine, la pastille redevient une simple icône.
class MoneyOverviewBloc extends Bloc<MoneyOverviewEvent, MoneyOverviewState> {
  MoneyOverviewBloc(
    this._repository,
    this._analytics, {
    this.trackViews = true,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const MoneyOverviewInitial()) {
    on<MoneyOverviewLoadRequested>(_onLoad);
    on<MoneyOverviewRefreshRequested>(_onRefresh);
  }

  final MoneyRepository _repository;
  final AnalyticsService _analytics;

  /// `false` pour la pastille et « Mes trajets » : seul l'écran « Mon
  /// argent » compte comme une consultation.
  final bool trackViews;

  /// Horloge des échéances (semaine en cours, prochaine, plus tard).
  final DateTime Function() _now;

  bool _viewTracked = false;

  Future<void> _onLoad(
    MoneyOverviewLoadRequested event,
    Emitter<MoneyOverviewState> emit,
  ) async {
    emit(const MoneyOverviewLoading());
    await _fetch(emit, keepOnError: false);
  }

  Future<void> _onRefresh(
    MoneyOverviewRefreshRequested event,
    Emitter<MoneyOverviewState> emit,
  ) async {
    try {
      await _fetch(emit, keepOnError: state is MoneyOverviewLoaded);
    } finally {
      final completer = event.completer;
      if (completer != null && !completer.isCompleted) completer.complete();
    }
  }

  Future<void> _fetch(
    Emitter<MoneyOverviewState> emit, {
    required bool keepOnError,
  }) async {
    try {
      final overview = await _repository.getOverview();
      if (emit.isDone) return;
      final loaded = MoneyOverviewLoaded(overview, now: _now());
      emit(loaded);
      _track(loaded, legacy: false);
    } on MoneyOverviewUnavailable {
      if (emit.isDone) return;
      final loaded = MoneyOverviewLoaded(
        const MoneyOverviewModel(),
        upcomingAvailable: false,
        now: _now(),
      );
      emit(loaded);
      _track(loaded, legacy: true);
    } catch (e) {
      // Rafraîchissement raté : on garde ce qui est affiché.
      if (emit.isDone || keepOnError) return;
      emit(MoneyOverviewError(unwrapDioError(e)));
    }
  }

  void _track(MoneyOverviewLoaded state, {required bool legacy}) {
    if (!trackViews || _viewTracked) return;
    _viewTracked = true;
    final overview = state.overview;
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.moneyOverviewViewed,
        properties: {
          'traveler_items': overview.travelerItems.length,
          'sender_items': overview.senderItems.length,
          'trip_count': state.schedule.trips.length,
          'legacy_backend': legacy,
        },
      ),
    );
  }
}
