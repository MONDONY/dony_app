import 'dart:async';
import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BidBloc extends Bloc<BidEvent, BidState> {
  final BidRepository _repository;
  final AnalyticsService _analytics;
  bool _checkoutInProgress = false;

  static const _myBidsTtl = Duration(minutes: 3);

  /// Statuts chargés par « mes colis » ([BidMyListRequested] et son
  /// rafraîchissement). Null = la liste complète, historique compris, dont ont
  /// besoin Mes colis et l'historique des livraisons. L'instance globale (accueil,
  /// feuilles de trajet) et le hub Activités ne regardent que les colis en cours :
  /// ils fixent ici leur ensemble pour ne plus recharger tout l'historique.
  Set<String>? myListStatuses;

  /// Charge aussi les offres de prix ouvertes, rangées dans
  /// [BidListLoaded.openNegotiations] et jamais dans les colis : l'instance
  /// globale (accueil, feuilles de trajet) marque « Offre envoyée » sur la carte
  /// du trajet (FLUTTER-GC). N'a d'effet qu'avec [myListStatuses].
  bool includeOpenNegotiations = false;

  Future<List<BidModel>> _loadMyBids() {
    final statuses = myListStatuses;
    return statuses == null
        ? _repository.getMyBids()
        : _repository.getMyBidsFiltered(
            statuses: statuses,
            includeNegotiating: includeOpenNegotiations,
          );
  }

  /// Sépare les offres ouvertes des colis : un écran qui lit [BidListLoaded.bids]
  /// ne voit jamais une discussion de prix.
  BidListLoaded _myList(List<BidModel> all) => BidListLoaded(
    [
      for (final b in all)
        if (b.status != kNegotiatingBidStatus) b,
    ],
    openNegotiations: [
      for (final b in all)
        if (b.status == kNegotiatingBidStatus) b,
    ],
  );

  BidBloc(this._repository, this._analytics) : super(BidInitial()) {
    on<BidCheckoutRequested>(_onCheckoutRequested);
    on<BidCreateRequested>(_onCreateRequested);
    on<BidListRequested>(_onListRequested);
    on<BidDetailRequested>(_onDetailRequested);
    on<BidDetailExternalChangeDetected>(_onExternalChangeDetected);
    on<BidAcceptRequested>(_onAcceptRequested);
    on<BidAcceptMobileMoneyRequested>(_onAcceptMobileMoneyRequested);
    on<BidRejectRequested>(_onRejectRequested);
    on<BidConfirmPresenceRequested>(_onConfirmPresenceRequested);
    on<BidMyListRequested>(_onMyListRequested);
    on<BidMyListAutoRefreshRequested>(_onMyListAutoRefreshRequested);
    on<BidCancelRequested>(_onCancelRequested);
    on<BidHideRequested>(_onHideRequested);
    on<BidCancelBeforePaymentRequested>(_onCancelBeforePaymentRequested);
    on<BidDeleteRequested>(_onDeleteRequested);
    on<BidTravelerDismissRequested>(_onTravelerDismissRequested);
    on<BidQuoteRequested>(_onQuoteRequested);
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
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bidSubmitted,
          properties: {
            'announcement_id': bid.announcementId,
            'weight_kg': bid.weightKg ?? 0.0,
            'price_per_kg': bid.pricePerKg ?? 0.0,
          },
        ),
      );
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
      final bids = await _repository.getBidsForAnnouncement(
        event.announcementId,
      );
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

  Future<void> _onExternalChangeDetected(
    BidDetailExternalChangeDetected event,
    Emitter<BidState> emit,
  ) async {
    final push = event.push;
    if (push != null && push['bidId']?.toString() != event.bidId) return;
    await _onDetailRequested(BidDetailRequested(event.bidId), emit);
  }

  Future<void> _onAcceptRequested(
    BidAcceptRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      final bid = await _repository.acceptBid(event.bidId);
      emit(BidAccepted(bid));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bidAccepted,
          properties: {'bid_id': bid.id},
        ),
      );
    } catch (e) {
      emit(BidError(unwrapDioError(e)));
    }
  }

  /// Acceptation d'un bid mobile money (pawaPay) : le voyageur n'a aucune
  /// interaction Stripe à effectuer, contrairement au cash (BidAcceptanceBloc)
  /// ou à la carte. Même gestion d'états/erreurs que [_onAcceptRequested].
  Future<void> _onAcceptMobileMoneyRequested(
    BidAcceptMobileMoneyRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      final bid = await _repository.acceptMobileMoneyBid(event.bidId);
      emit(BidAccepted(bid));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bidAccepted,
          properties: {'bid_id': bid.id, 'payment_method': 'mobile_money'},
        ),
      );
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
      final bid = await _repository.rejectBid(
        event.bidId,
        reason: event.reason,
      );
      emit(BidRejected(bid));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bidRejected,
          properties: {
            'bid_id': bid.id,
            // Code de la liste fermée (FLUTTER-AF), jamais un texte saisi.
            if (event.reason != null) 'reason': event.reason!,
          },
        ),
      );
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
      final bids = await _loadMyBids();
      emit(_myList(bids));
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
      emit(
        BidListLoaded(
          current.bids,
          fetchedAt: current.fetchedAt,
          isRefreshing: true,
          openNegotiations: current.openNegotiations,
        ),
      );
      try {
        final bids = await _loadMyBids();
        emit(_myList(bids));
      } on DioException catch (_) {
        // On garde les anciennes données en cas d'erreur réseau
        emit(
          BidListLoaded(
            current.bids,
            fetchedAt: current.fetchedAt,
            openNegotiations: current.openNegotiations,
          ),
        );
      } catch (_) {
        emit(
          BidListLoaded(
            current.bids,
            fetchedAt: current.fetchedAt,
            openNegotiations: current.openNegotiations,
          ),
        );
      }
    } else {
      // Pas encore de données → chargement initial normal
      emit(BidLoading());
      try {
        final bids = await _loadMyBids();
        emit(_myList(bids));
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
      final bid = await _repository.cancelBid(
        event.bidId,
        reason: event.reason,
      );
      emit(BidCancelled(bid));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bidCancelled,
          properties: {'actor': event.actor, 'status': bid.status},
        ),
      );
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

  /// Vraie annulation avant paiement. Trois issues :
  /// - succès → [BidCancelledBeforePayment] ;
  /// - back antérieur (404 sans code métier, route inconnue, ou 405) → repli
  ///   sur le masquage d'avant, [BidDeleted] (PR jumelle, l'app peut précéder
  ///   le déploiement du back) ;
  /// - refus (409 : paiement déjà validé ou en cours) → [BidError] puis la
  ///   fiche relue, pour que l'écran montre l'état réel du colis.
  Future<void> _onCancelBeforePaymentRequested(
    BidCancelBeforePaymentRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      final already = await _repository.cancelBeforePayment(event.bidId);
      emit(BidCancelledBeforePayment(alreadyCancelled: already));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.bidCancelledBeforePayment,
          properties: {
            'payment_method': event.paymentMethod,
            'already_cancelled': already,
            'fallback': false,
          },
        ),
      );
    } catch (e) {
      final error = unwrapDioError(e);
      if (_isLegacyBackend(error)) {
        try {
          await _repository.hideBid(event.bidId);
          emit(BidDeleted());
          unawaited(
            _analytics.logEvent(
              AnalyticsEvents.bidCancelledBeforePayment,
              properties: {
                'payment_method': event.paymentMethod,
                'fallback': true,
              },
            ),
          );
        } catch (e2) {
          emit(BidError(unwrapDioError(e2)));
        }
        return;
      }
      emit(BidError(error));
      if (error is ConflictException) {
        try {
          emit(BidDetailLoaded(await _repository.getBidById(event.bidId)));
        } catch (_) {
          // Fiche illisible : l'erreur est déjà affichée, le polling relira.
        }
      }
    }
  }

  /// Back sans l'endpoint : 404 « No endpoint matches this path » (aucun
  /// code métier, d'où le code synthétique `NOT_FOUND`) ou 405. Un 404
  /// `bid-not-found` vient du nouveau back : la demande n'existe plus.
  static bool _isLegacyBackend(AppException error) {
    if (error is NotFoundException) return error.code == 'NOT_FOUND';
    return error.code == '405';
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
      const promoCodes = {
        'promo-not-found',
        'promo-expired',
        'promo-limit-reached',
        'promo-not-eligible',
      };
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
