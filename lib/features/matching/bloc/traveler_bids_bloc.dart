import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/traveler_bids_event.dart';
import 'package:dony/features/matching/bloc/traveler_bids_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Demandes reçues sur l'ensemble des trajets du voyageur.
///
/// S'appuie sur `GET /travelers/me/bids`, qui couvre tous les trajets en un
/// appel — là où `/bids/me` ne renvoie que les bids créés en tant
/// qu'expéditeur.
class TravelerBidsBloc extends Bloc<TravelerBidsEvent, TravelerBidsState> {
  static const _pageSize = 20;

  /// Garde-fou : au-delà (200 demandes), on s'arrête et `hasMore` reprend la
  /// main via le scroll infini.
  static const _maxInitialPages = 10;

  final BidRepository _repository;
  final AnalyticsService _analytics;

  /// Toutes les demandes sont chargées d'un bloc puis filtrées côté client :
  /// les compteurs par onglet doivent rester justes sans un appel par filtre.
  TravelerBidsBloc(this._repository, this._analytics)
    : super(const TravelerBidsInitial()) {
    on<TravelerBidsRequested>(_onRequested);
    on<TravelerBidsNextPageRequested>(_onNextPageRequested);
    on<TravelerBidsFilterChanged>(_onFilterChanged);
  }

  Future<void> _onRequested(
    TravelerBidsRequested event,
    Emitter<TravelerBidsState> emit,
  ) async {
    final current = state;
    if (current is TravelerBidsLoaded && !event.force) {
      return;
    }

    final filter = current is TravelerBidsLoaded
        ? current.filter
        : TravelerBidFilter.aTraiter;

    if (current is! TravelerBidsLoaded) {
      emit(const TravelerBidsLoading());
    }

    try {
      // Toutes les pages d'un coup (avec garde-fou) : les compteurs de la
      // tuile du hub et des chips seraient faux sur la seule première page.
      final bids = <BidModel>[];
      var page = 0;
      var isLast = false;
      while (!isLast && page < _maxInitialPages) {
        final result = await _repository.getTravelerBids(
          page: page,
          size: _pageSize,
        );
        bids.addAll(result.content);
        isLast = result.isLast;
        // Compteur local, jamais `result.page` : un serveur qui renverrait
        // toujours le même numéro de page bloquerait le garde-fou et la
        // boucle tournerait à l'infini.
        page++;
      }
      emit(
        TravelerBidsLoaded(
          bids: bids,
          page: page - 1,
          hasMore: !isLast,
          filter: filter,
        ),
      );
    } catch (e) {
      // Un refresh raté ne doit pas vider une liste déjà affichée.
      if (current is TravelerBidsLoaded) {
        emit(current);
      } else {
        emit(TravelerBidsError(unwrapDioError(e)));
      }
    }
  }

  Future<void> _onNextPageRequested(
    TravelerBidsNextPageRequested event,
    Emitter<TravelerBidsState> emit,
  ) async {
    final current = state;
    if (current is! TravelerBidsLoaded ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true));
    try {
      final result = await _repository.getTravelerBids(
        page: current.page + 1,
        size: _pageSize,
      );
      emit(
        current.copyWith(
          bids: [...current.bids, ...result.content],
          page: result.page,
          hasMore: !result.isLast,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  void _onFilterChanged(
    TravelerBidsFilterChanged event,
    Emitter<TravelerBidsState> emit,
  ) {
    final current = state;
    if (current is TravelerBidsLoaded) {
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.travelerBidsFilterApplied,
          properties: {'filter': event.filter.name},
        ),
      );
      emit(current.copyWith(filter: event.filter));
    }
  }
}
