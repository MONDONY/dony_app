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
  /// Garde-fou : au-delà (200 demandes), on s'arrête et `hasMore` reprend la
  /// main via le scroll infini.
  static const _maxInitialPages = 10;

  final BidRepository _repository;
  final AnalyticsService _analytics;

  /// Numéro du dernier chargement lancé. Les chargements tournent en
  /// parallèle (hub, shell et écran en lancent chacun un à l'ouverture) :
  /// seul le plus récent a le droit d'émettre, sinon une réponse lente et
  /// périmée écraserait une liste plus fraîche.
  int _generation = 0;

  /// Choix automatique de l'onglet demandé par l'ouverture de l'écran
  /// ([TravelerBidsRequested.autoSelectFilter]), en attente du prochain
  /// chargement abouti. Porté par le bloc et non par l'événement : un
  /// chargement plus récent (hub, push) peut doubler celui de l'écran.
  bool _autoSelectPending = false;

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
      event.done?.complete();
      return;
    }
    if (event.autoSelectFilter) _autoSelectPending = true;
    final generation = ++_generation;

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
        final result = await _repository.getTravelerBids(page: page);
        bids.addAll(result.content);
        isLast = result.isLast;
        // Compteur local, jamais `result.page` : un serveur qui renverrait
        // toujours le même numéro de page bloquerait le garde-fou et la
        // boucle tournerait à l'infini.
        page++;
      }
      if (generation != _generation) {
        event.done?.complete();
        return;
      }
      final loaded = TravelerBidsLoaded(
        bids: bids,
        page: page - 1,
        hasMore: !isLast,
        // Le filtre courant, pas celui du départ : l'utilisateur a pu
        // changer d'onglet pendant le chargement.
        filter: state is TravelerBidsLoaded
            ? (state as TravelerBidsLoaded).filter
            : filter,
      );
      final autoSelect = _autoSelectPending;
      _autoSelectPending = false;
      emit(autoSelect ? loaded.copyWith(filter: loaded.openingFilter) : loaded);
      event.done?.complete();
    } catch (e) {
      final error = unwrapDioError(e);
      event.done?.complete(error);
      if (generation != _generation) return;
      // Sans données fraîches, pas de décision : l'onglet reste celui affiché.
      _autoSelectPending = false;
      // Un refresh raté ne doit pas vider une liste déjà affichée.
      if (state is! TravelerBidsLoaded) {
        emit(TravelerBidsError(error));
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
      final result = await _repository.getTravelerBids(page: current.page + 1);
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
    // Un onglet choisi (par l'utilisateur ou imposé) l'emporte sur le choix
    // automatique de l'ouverture.
    _autoSelectPending = false;
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
