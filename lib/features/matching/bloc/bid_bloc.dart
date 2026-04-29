import 'package:dio/dio.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BidBloc extends Bloc<BidEvent, BidState> {
  final BidRepository _repository;

  static const _myBidsTtl = Duration(minutes: 3);

  BidBloc(this._repository) : super(BidInitial()) {
    on<BidCreateRequested>(_onCreateRequested);
    on<BidListRequested>(_onListRequested);
    on<BidDetailRequested>(_onDetailRequested);
    on<BidAcceptRequested>(_onAcceptRequested);
    on<BidRejectRequested>(_onRejectRequested);
    on<BidHandoverRequested>(_onHandoverRequested);
    on<BidConfirmPresenceRequested>(_onConfirmPresenceRequested);
    on<BidMyListRequested>(_onMyListRequested);
    on<BidMyListAutoRefreshRequested>(_onMyListAutoRefreshRequested);
    on<BidCancelRequested>(_onCancelRequested);
    on<BidHideRequested>(_onHideRequested);
    on<BidDeleteRequested>(_onDeleteRequested);
    on<BidTravelerDismissRequested>(_onTravelerDismissRequested);
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
      );
      emit(BidCreated(bid));
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? e.message ?? 'Erreur inconnue';
      emit(BidError(detail));
    } catch (e) {
      emit(BidError(e.toString()));
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
    } on DioException catch (e) {
      if (e.error is NotFoundException) {
        emit(BidNotFound());
      } else {
        final detail = e.response?.data?['detail'] ?? e.message ?? 'Erreur inconnue';
        emit(BidError(detail));
      }
    } catch (e) {
      emit(BidError(e.toString()));
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
    } on DioException catch (e) {
      if (e.error is NotFoundException) {
        emit(BidNotFound());
      }
      // Autres erreurs réseau : silence intentionnel
    } catch (_) {
      // silence
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
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? e.message ?? 'Erreur inconnue';
      emit(BidError(detail));
    } catch (e) {
      emit(BidError(e.toString()));
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
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? e.message ?? 'Erreur inconnue';
      emit(BidError(detail));
    } catch (e) {
      emit(BidError(e.toString()));
    }
  }

  Future<void> _onHandoverRequested(
    BidHandoverRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      final bid = await _repository.setHandover(
        bidId: event.bidId,
        location: event.location,
        windowStart: event.windowStart,
        windowEnd: event.windowEnd,
      );
      emit(BidHandoverSet(bid));
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? e.message ?? 'Erreur inconnue';
      emit(BidError(detail));
    } catch (e) {
      emit(BidError(e.toString()));
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
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? e.message ?? 'Erreur inconnue';
      emit(BidError(detail));
    } catch (e) {
      emit(BidError(e.toString()));
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
    } on DioException catch (e) {
      final detail =
          e.response?.data?['detail'] ?? e.message ?? 'Erreur inconnue';
      emit(BidError(detail));
    } catch (e) {
      emit(BidError(e.toString()));
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
      if (!stale && !event.force) return;

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
      } on DioException catch (e) {
        final detail =
            e.response?.data?['detail'] ?? e.message ?? 'Erreur inconnue';
        emit(BidError(detail));
      } catch (e) {
        emit(BidError(e.toString()));
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
    } on DioException catch (e) {
      final detail =
          e.response?.data?['detail'] ?? e.message ?? 'Erreur inconnue';
      emit(BidError(detail));
    } catch (e) {
      emit(BidError(e.toString()));
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
    } on DioException catch (e) {
      final detail =
          e.response?.data?['detail'] ?? e.message ?? 'Erreur inconnue';
      emit(BidError(detail));
    } catch (e) {
      emit(BidError(e.toString()));
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
    } on DioException catch (e) {
      final detail =
          e.response?.data?['detail'] ?? e.message ?? 'Erreur inconnue';
      emit(BidError(detail));
    } catch (e) {
      emit(BidError(e.toString()));
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
    } on DioException catch (e) {
      final detail =
          e.response?.data?['detail'] ?? e.message ?? 'Erreur inconnue';
      emit(BidError(detail));
    } catch (e) {
      emit(BidError(e.toString()));
    }
  }
}
