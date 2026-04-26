import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  final TrackingRepository _repository;

  TrackingBloc(this._repository) : super(TrackingInitial()) {
    on<TrackingQrCodeRequested>(_onQrCodeRequested);
    on<TrackingSearchRequested>(_onSearchRequested);
  }

  Future<void> _onQrCodeRequested(
    TrackingQrCodeRequested event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingQrLoading());
    try {
      final qrCode = await _repository.getQrCode(event.bidId);
      emit(TrackingQrLoaded(qrCode));
    } catch (e) {
      emit(TrackingQrError('Impossible de charger le QR code'));
    }
  }

  Future<void> _onSearchRequested(
    TrackingSearchRequested event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingSearchLoading());
    try {
      final result = await _repository.searchByTrackingNumber(event.number);
      emit(TrackingSearchLoaded(result));
    } catch (e) {
      emit(TrackingSearchError('Numéro de suivi introuvable. Vérifiez le numéro et réessayez.'));
    }
  }
}
