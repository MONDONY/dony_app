import 'dart:async';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BidBloc extends Bloc<BidEvent, BidState> {
  final BidRepository _repository;
  final AnalyticsService _analytics;
  bool _checkoutInProgress = false;

  static const _myBidsTtl = Duration(minutes: 3);

  BidBloc(this._repository, this._analytics) : super(BidInitial()) {
    on<BidCheckoutRequested>(_onCheckoutRequested);
    on<BidCreateRequested>(_onCreateRequested);
    on<BidListRequested>(_onListRequested);
    on<BidDetailRequested>(_onDetailRequested);
    on<BidAcceptRequested>(_onAcceptRequested);
    on<BidRejectRequested>(_onRejectRequested);
    on<BidConfirmPresenceRequested>(_onConfirmPresenceRequested);
    on<BidMyListRequested>(_onMyListRequested);
    on<BidMyListAutoRefreshRequested>(_onMyListAutoRefreshRequested);
    on<BidCancelRequested>(_onCancelRequested);
    on<BidHideRequested>(_onHideRequested);
    on<BidDeleteRequested>(_onDeleteRequested);
    on<BidTravelerDismissRequested>(_onTravelerDismissRequested);
    on<BidConfirmPaymentRequested>(_onConfirmPaymentRequested);
    on<BidQuoteRequested>(_onQuoteRequested);
  }

  Future<void> _onConfirmPaymentRequested(
    BidConfirmPaymentRequested event,
    Emitter<BidState> emit,
  ) async {
    try {
      final bid = await _repository.confirmPayment(event.bidId);
      emit(BidPaymentConfirmed(bid));
    } catch (e) {
      emit(BidError(unwrapDioError(e)));
    }
  }

  Future<void> _onCheckoutRequested(
    BidCheckoutRequested event,
    Emitter<BidState> emit,
  ) async {
    if (_checkoutInProgress) return;
    _checkoutInProgress = true;
    emit(BidLoading());
    try {
      final response = await _repository.checkoutBid(
        announcementId: event.announcementId,
        weightKg: event.weightKg,
        declaredValueEur: event.declaredValueEur,
        description: event.description,
        contentCategory: event.contentCategory,
        recipientName: event.recipientName,
        recipientPhone: event.recipientPhone,
        photoKeys: event.photoKeys,
        gridItems: event.gridItems,
      );
      emit(BidCheckoutReady(response));
    } catch (e) {
      emit(BidError(unwrapDioError(e)));
    } finally {
      _checkoutInProgress = false;
    }
  }

  Future<void> _onCreateRequested(
    BidCreateRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      final bid = await _repository.createBid(
        announcementId: event.announcementId,
        weightKg: event.weightKg,
        declaredValueEur: event.declaredValueEur,
        description: event.description,
        contentCategory: event.contentCategory,
        recipientName: event.recipientName,
        recipientPhone: event.recipientPhone,
        paymentMethod: event.paymentMethod,
        phoneNumber: event.phoneNumber,
        countryCode: event.countryCode,
        promoCode: event.promoCode,
        photoKeys: event.photoKeys,
        gridItems: event.gridItems,
      );
      emit(BidCreated(bid));
      unawaited(_analytics.logEvent(
        AnalyticsEvents.bidSubmitted,
        properties: {
          'announcement_id': bid.announcementId,
          'weight_kg': bid.weightKg ?? 0.0,
          'price_per_kg': bid.pricePerKg ?? 0.0,
        },
      ));
    } catch (e) {
      emit(BidError(unwrapDioError(e)));
    }
  }

  Future<void> _onListRequested(
    BidListRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      final bids = await _repository.getBidsForAnnouncement(event.announcementId);
      emit(BidListLoaded(bids));
    } catch (e) {
      final wrapped = unwrapDioError(e);
      if (wrapped is NotFoundException) {
        emit(BidNotFound());
      } else {
        emit(BidError(wrapped));
      }
    }
  }

  Future<void> _onDetailRequested(
    BidDetailRequested event,
    Emitter<BidState> emit,
  ) async {
    // Pas de BidLoading : refresh silencieux — ne pas désactiver les boutons.
    try {
      final bid = await _repository.getBidById(event.bidId);
      emit(BidDetailLoaded(bid));
    } catch (e) {
      final wrapped = unwrapDioError(e);
      if (wrapped is NotFoundException) {
        emit(BidNotFound());
      }
      // Autres erreurs réseau : silence intentionnel
    }
  }

  Future<void> _onAcceptRequested(
    BidAcceptRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      final bid = await _repository.acceptBid(event.bidId);
      emit(BidAccepted(bid));
    } catch (e) {
      emit(BidError(unwrapDioError(e)));
    }
  }

  Future<void> _onRejectRequested(
    BidRejectRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      final bid = await _repository.rejectBid(event.bidId, reason: event.reason);
      emit(BidRejected(bid));
      unawaited(_analytics.logEvent(
        AnalyticsEvents.bidRejected,
        properties: {'bid_id': bid.id},
      ));
    } catch (e) {
      emit(BidError(unwrapDioError(e)));
    }
  }

  Future<void> _onConfirmPresenceRequested(
    BidConfirmPresenceRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      final bid = await _repository.confirmPresence(event.bidId);
      emit(BidPresenceConfirmed(bid));
    } catch (e) {
      emit(BidError(unwrapDioError(e)));
    }
  }

  Future<void> _onMyListRequested(
    BidMyListRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      final bids = await _repository.getMyBids();
      emit(BidListLoaded(bids));
    } catch (e) {
      emit(BidError(unwrapDioError(e)));
    }
  }

  Future<void> _onMyListAutoRefreshRequested(
    BidMyListAutoRefreshRequested event,
    Emitter<BidState> emit,
  ) async {
    final current = state;

    if (current is BidListLoaded) {
      final stale = DateTime.now().difference(current.fetchedAt) > _myBidsTtl;
      // Données fraîches et pas de force → rien à faire
      if (!stale && !event.force) {
        return;
      }

      // Données périmées → refresh silencieux (pas de BidLoading, l'UI reste visible)
      emit(BidListLoaded(current.bids,
          fetchedAt: current.fetchedAt, isRefreshing: true));
      try {
        final bids = await _repository.getMyBids();
        emit(BidListLoaded(bids));
      } on DioException catch (_) {
        // On garde les anciennes données en cas d'erreur réseau
        emit(BidListLoaded(current.bids, fetchedAt: current.fetchedAt));
      } catch (_) {
        emit(BidListLoaded(current.bids, fetchedAt: current.fetchedAt));
      }
    } else {
      // Pas encore de données → chargement initial normal
      emit(BidLoading());
      try {
        final bids = await _repository.getMyBids();
        emit(BidListLoaded(bids));
      } catch (e) {
        emit(BidError(unwrapDioError(e)));
      }
    }
  }

  Future<void> _onCancelRequested(
    BidCancelRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      final bid = await _repository.cancelBid(event.bidId, reason: event.reason);
      emit(BidCancelled(bid));
    } catch (e) {
      emit(BidError(unwrapDioError(e)));
    }
  }

  Future<void> _onHideRequested(
    BidHideRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      await _repository.hideBid(event.bidId);
      emit(BidHidden());
    } catch (e) {
      emit(BidError(unwrapDioError(e)));
    }
  }

  Future<void> _onDeleteRequested(
    BidDeleteRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      await _repository.hideBid(event.bidId);
      emit(BidDeleted());
    } catch (e) {
      emit(BidError(unwrapDioError(e)));
    }
  }

  Future<void> _onTravelerDismissRequested(
    BidTravelerDismissRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      await _repository.dismissBidAsTraveler(event.bidId);
      emit(BidDeleted());
    } catch (e) {
      emit(BidError(unwrapDioError(e)));
    }
  }

  /// Calcule le devis (net/commission/total) avec promo éventuel.
  /// Émet [BidQuoteLoaded] si OK, [BidPromoError] si le promo est invalide.
  Future<void> _onQuoteRequested(
    BidQuoteRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidQuoteLoading());
    try {
      final quote = await _repository.quoteBid(
        announcementId: event.announcementId,
        weightKg: event.weightKg,
        promoCode: event.promoCode,
        gridItems: event.gridItems,
      );
      emit(BidQuoteLoaded(quote));
    } on DioException catch (e) {
      final wrapped = unwrapDioError(e);
      // Erreurs promo → BidPromoError (ne polluent pas les autres états du BLoC).
      const promoCodes = {'promo-not-found', 'promo-expired', 'promo-limit-reached', 'promo-not-eligible'};
      if (promoCodes.contains(wrapped.code)) {
        emit(BidPromoError(wrapped));
      } else {
        emit(BidError(wrapped));
      }
    } catch (e) {
      emit(BidError(unwrapDioError(e)));
    }
  }

}
