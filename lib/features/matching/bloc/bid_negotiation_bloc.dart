import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_state.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Fil de négociation du prix d'un trajet.
///
/// Style identique à [BidBloc] : le repository ne fait que passer, c'est ici
/// que les erreurs sont déballées (`unwrapDioError`) et que les events
/// analytics sont tirés, toujours en `unawaited`.
class BidNegotiationBloc
    extends Bloc<BidNegotiationEvent, BidNegotiationState> {
  final BidNegotiationRepository _repository;
  final AnalyticsService _analytics;

  BidNegotiationBloc(this._repository, this._analytics)
    : super(const BidNegotiationInitial()) {
    on<BidNegotiationFetchRequested>(_onFetch);
    on<BidNegotiationOpenRequested>(_onOpen);
    on<BidNegotiationProposeRequested>(_onPropose);
    on<BidNegotiationCounterRequested>(_onCounter);
    on<BidNegotiationAcceptRequested>(_onAccept);
    on<BidNegotiationRejectRequested>(_onReject);
    on<BidNegotiationCancelRequested>(_onCancel);
    on<BidNegotiationReadRequested>(_onRead);
  }

  /// Dernier fil connu : sert à garder l'écran affichable derrière une erreur.
  ///
  /// Champ dédié et non lecture de `state` : chaque action émet d'abord
  /// [BidNegotiationLoading], donc au moment du `catch` le state a déjà oublié
  /// le fil.
  BidNegotiation? _cachedThread;

  void _emitLoaded(
    BidNegotiation thread,
    BidNegotiationAction action,
    Emitter<BidNegotiationState> emit,
  ) {
    _cachedThread = thread;
    emit(BidNegotiationLoaded(thread, action: action));
  }

  void _emitError(Object e, Emitter<BidNegotiationState> emit) {
    emit(BidNegotiationError(unwrapDioError(e), negotiation: _cachedThread));
  }

  Future<void> _onFetch(
    BidNegotiationFetchRequested event,
    Emitter<BidNegotiationState> emit,
  ) async {
    emit(const BidNegotiationLoading());
    try {
      final thread = await _repository.thread(event.bidId);
      _emitLoaded(thread, BidNegotiationAction.fetched, emit);
    } catch (e) {
      _emitError(e, emit);
    }
  }

  /// Ouverture du mode négociation. Aucun appel réseau : seul l'entonnoir
  /// est mesuré, la proposition elle-même viendra plus tard (ou jamais).
  void _onOpen(
    BidNegotiationOpenRequested event,
    Emitter<BidNegotiationState> emit,
  ) {
    unawaited(
      _analytics.logEvent(
        AnalyticsEvents.tripNegotiationOpened,
        properties: {'announcement_id': event.announcementId},
      ),
    );
  }

  Future<void> _onPropose(
    BidNegotiationProposeRequested event,
    Emitter<BidNegotiationState> emit,
  ) async {
    emit(const BidNegotiationLoading());
    try {
      final thread = await _repository.propose(
        announcementId: event.announcementId,
        weightKg: event.weightKg,
        description: event.description,
        contentCategory: event.contentCategory,
        recipientName: event.recipientName,
        recipientPhone: event.recipientPhone,
        proposedTotalEur: event.proposedTotalEur,
        paymentMethod: event.paymentMethod,
        phoneNumber: event.phoneNumber,
        countryCode: event.countryCode,
        photoKeys: event.photoKeys,
        customItems: event.customItems,
        gridItems: event.gridItems,
      );
      _emitLoaded(thread, BidNegotiationAction.proposed, emit);
      // Ni description, ni destinataire, ni téléphone : la seule chose utile
      // ici est de savoir si la proposition portait des articles hors grille,
      // c'est le motif de négociation qu'on cherche à mesurer.
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripNegotiationProposed,
          properties: {
            'announcement_id': event.announcementId,
            'has_custom_items': (event.customItems ?? const []).isNotEmpty,
            'custom_item_count': (event.customItems ?? const []).length,
          },
        ),
      );
    } catch (e) {
      _emitError(e, emit);
    }
  }

  Future<void> _onCounter(
    BidNegotiationCounterRequested event,
    Emitter<BidNegotiationState> emit,
  ) async {
    emit(const BidNegotiationLoading());
    try {
      final thread = await _repository.counter(
        event.bidId,
        proposedTotalEur: event.proposedTotalEur,
        body: event.body,
      );
      _emitLoaded(thread, BidNegotiationAction.countered, emit);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripNegotiationCountered,
          properties: {
            'bid_id': thread.bidId,
            'round': thread.round,
            'actor': thread.viewerRole,
          },
        ),
      );
    } catch (e) {
      _emitError(e, emit);
    }
  }

  Future<void> _onAccept(
    BidNegotiationAcceptRequested event,
    Emitter<BidNegotiationState> emit,
  ) async {
    emit(const BidNegotiationLoading());
    try {
      final thread = await _repository.accept(event.bidId);
      _emitLoaded(thread, BidNegotiationAction.accepted, emit);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripNegotiationAccepted,
          properties: {
            'bid_id': thread.bidId,
            'round': thread.round,
            'actor': thread.viewerRole,
          },
        ),
      );
    } catch (e) {
      _emitError(e, emit);
    }
  }

  Future<void> _onReject(
    BidNegotiationRejectRequested event,
    Emitter<BidNegotiationState> emit,
  ) async {
    emit(const BidNegotiationLoading());
    try {
      final thread = await _repository.reject(event.bidId);
      _emitLoaded(thread, BidNegotiationAction.rejected, emit);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripNegotiationRejected,
          properties: {
            'bid_id': thread.bidId,
            'round': thread.round,
            'actor': thread.viewerRole,
          },
        ),
      );
    } catch (e) {
      _emitError(e, emit);
    }
  }

  Future<void> _onCancel(
    BidNegotiationCancelRequested event,
    Emitter<BidNegotiationState> emit,
  ) async {
    emit(const BidNegotiationLoading());
    try {
      final thread = await _repository.cancel(event.bidId);
      _emitLoaded(thread, BidNegotiationAction.cancelled, emit);
    } catch (e) {
      _emitError(e, emit);
    }
  }

  /// Accusé de lecture : purement cosmétique (badge de non-lus). Un échec ne
  /// doit jamais faire clignoter une erreur sur un fil parfaitement lisible.
  Future<void> _onRead(
    BidNegotiationReadRequested event,
    Emitter<BidNegotiationState> emit,
  ) async {
    try {
      await _repository.markRead(event.bidId);
    } catch (_) {
      // Silence intentionnel.
    }
  }
}
