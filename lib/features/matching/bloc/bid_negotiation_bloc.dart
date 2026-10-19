import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/config/data/commission_grid_preload.dart';
import 'package:dony/features/config/data/config_repository.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_event.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/models/bid_negotiation.dart';
import 'package:dony/features/matching/data/repositories/bid_negotiation_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Fil de négociation du prix d'un trajet.
///
/// Style identique à [BidBloc] : le repository ne fait que passer, c'est ici
/// que les erreurs sont déballées (`unwrapDioError`) et que les events
/// analytics sont tirés, toujours en `unawaited`.
///
/// Avant d'émettre un fil encore en négociation vu par le voyageur, sa grille
/// de commission figée (`commissionGridId`) est chargée dans le magasin des
/// grilles : l'aperçu de sa contre-offre en net se calcule sur la grille du
/// bid, pas sur celle du jour. L'expéditeur, lui, ne calcule rien localement
/// (il saisit un brut et lit les frais servis) : son fil n'attend pas.
class BidNegotiationBloc
    extends Bloc<BidNegotiationEvent, BidNegotiationState> {
  final BidNegotiationRepository _repository;
  final AnalyticsService _analytics;
  final IConfigRepository _config;
  final Duration _gridTimeout;

  BidNegotiationBloc(
    this._repository,
    this._analytics,
    this._config, {
    Duration gridTimeout = kCommissionGridPreloadTimeout,
  }) : _gridTimeout = gridTimeout,
       super(const BidNegotiationInitial()) {
    on<BidNegotiationFetchRequested>(_onFetch);
    on<BidNegotiationOpenRequested>(_onOpen);
    on<BidNegotiationProposeRequested>(_onPropose);
    on<BidNegotiationCounterRequested>(_onCounter);
    on<BidNegotiationAcceptRequested>(_onAccept);
    on<BidNegotiationRejectRequested>(_onReject);
    on<BidNegotiationCancelRequested>(_onCancel);
    on<BidNegotiationReadRequested>(_onRead);
    on<BidNegotiationCheckoutRequested>(_onCheckout);
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

  /// Charge la grille figée de [thread] si l'app ne la connaît pas encore,
  /// seulement quand elle sert : fil vu par le voyageur et encore ouvert à la
  /// contre-offre. Ne lève jamais et rend la main au plus tard après
  /// [_gridTimeout] : un échec ou une lenteur laisse la grille en vigueur
  /// servir de repli.
  Future<BidNegotiation> _withGrid(BidNegotiation thread) async {
    if (thread.isTravelerView && !thread.isClosed) {
      await preloadCommissionGrids(
        [thread.commissionGridId],
        _config.getCommissionGridById,
        timeout: _gridTimeout,
      );
    }
    return thread;
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
      final thread = await _withGrid(await _repository.thread(event.bidId));
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
      // La réponse d'une proposition est toujours en vue expéditeur : aucune
      // grille figée à précharger (voir `_withGrid`).
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
      // Ni description, ni destinataire, ni téléphone : on mesure si la
      // proposition portait des articles hors grille (le motif de négociation)
      // et le mode de paiement choisi à l'étape « Comment veux-tu payer ? ».
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripNegotiationProposed,
          properties: {
            'announcement_id': event.announcementId,
            'has_custom_items': (event.customItems ?? const []).isNotEmpty,
            'custom_item_count': (event.customItems ?? const []).length,
            'payment_method': event.paymentMethod.apiValue,
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
      final thread = await _withGrid(
        await _repository.counter(
          event.bidId,
          proposedTotalEur: event.proposedTotalEur,
          proposedNetEur: event.proposedNetEur,
          body: event.body,
        ),
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
      final thread = await _withGrid(await _repository.accept(event.bidId));
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
      final thread = await _withGrid(await _repository.reject(event.bidId));
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
      final thread = await _withGrid(await _repository.cancel(event.bidId));
      _emitLoaded(thread, BidNegotiationAction.cancelled, emit);
      // Le retrait de l'offre côté trajet n'était pas tracé, contrairement au
      // refus : la fin du fil restait invisible.
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripNegotiationCancelled,
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

  /// Paiement d'un accord scellé côté carte.
  ///
  /// Aucune garde d'appel concurrent ici, contrairement à [BidBloc] : le
  /// serveur est idempotent, un double tap renvoie le même `clientSecret`. Le
  /// [BidNegotiationLoading] émis d'abord garantit malgré tout la transition,
  /// sans quoi un second état Equatable-égal serait avalé en silence.
  Future<void> _onCheckout(
    BidNegotiationCheckoutRequested event,
    Emitter<BidNegotiationState> emit,
  ) async {
    emit(const BidNegotiationLoading());
    try {
      final checkout = await _repository.negotiationCheckout(event.bidId);
      emit(BidNegotiationCheckoutReady(checkout, negotiation: _cachedThread));
      // Ni montant ni destinataire : seule l'entrée dans le tunnel de paiement
      // d'un accord négocié est mesurée.
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.tripNegotiationPaymentStarted,
          properties: {'bid_id': event.bidId},
        ),
      );
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
