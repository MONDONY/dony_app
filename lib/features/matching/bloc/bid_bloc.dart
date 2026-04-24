import 'package:dio/dio.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/bid_state.dart';
import 'package:dony/features/matching/data/repositories/bid_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BidBloc extends Bloc<BidEvent, BidState> {
  final BidRepository _repository;

  BidBloc(this._repository) : super(BidInitial()) {
    on<BidCreateRequested>(_onCreateRequested);
    on<BidListRequested>(_onListRequested);
    on<BidDetailRequested>(_onDetailRequested);
    on<BidAcceptRequested>(_onAcceptRequested);
    on<BidRejectRequested>(_onRejectRequested);
    on<BidHandoverRequested>(_onHandoverRequested);
    on<BidConfirmPresenceRequested>(_onConfirmPresenceRequested);
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
      final detail = e.response?.data?['detail'] ?? e.message ?? 'Erreur inconnue';
      emit(BidError(detail));
    } catch (e) {
      emit(BidError(e.toString()));
    }
  }

  Future<void> _onDetailRequested(
    BidDetailRequested event,
    Emitter<BidState> emit,
  ) async {
    emit(BidLoading());
    try {
      final bid = await _repository.getBidById(event.bidId);
      emit(BidDetailLoaded(bid));
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? e.message ?? 'Erreur inconnue';
      emit(BidError(detail));
    } catch (e) {
      emit(BidError(e.toString()));
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
}
