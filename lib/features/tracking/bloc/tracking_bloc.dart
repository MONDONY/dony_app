import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  final TrackingRepository _repository;
  final OfflineSyncService _offlineSync;
  final AnalyticsService _analytics;

  TrackingBloc(this._repository, this._offlineSync, this._analytics) : super(TrackingInitial()) {
    on<TrackingQrCodeRequested>(_onQrCodeRequested);
    on<TrackingSearchRequested>(_onSearchRequested);
    on<TrackingEventsRequested>(_onEventsRequested);
    on<TrackingConfirmCodeRequested>(_onConfirmCodeRequested);
    on<TrackingRefreshCodeRequested>(_onRefreshCodeRequested);
    on<QrScanSubmitRequested>(_onScanSubmit);
    on<ConfirmDeliveryRequested>(_onConfirmDelivery);
    on<OfflineSyncRequested>(_onOfflineSync);
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
      emit(TrackingQrError(unwrapDioError(e)));
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
      emit(TrackingSearchError(unwrapDioError(e)));
    }
  }

  Future<void> _onEventsRequested(
    TrackingEventsRequested event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingEventsLoading());
    try {
      final events = await _repository.getEvents(event.bidId);
      emit(TrackingEventsLoaded(events));
    } catch (e) {
      if (kDebugMode) debugPrint('[TrackingBloc] getEvents error: $e');
      emit(TrackingEventsError(unwrapDioError(e)));
    }
  }

  Future<void> _onConfirmCodeRequested(
    TrackingConfirmCodeRequested event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingConfirmCodeLoading());
    try {
      final result = await _repository.getConfirmationCode(event.bidId);
      emit(TrackingConfirmCodeLoaded(result.code, expiresAt: result.expiresAt));
    } catch (e) {
      emit(TrackingConfirmCodeError());
    }
  }

  Future<void> _onRefreshCodeRequested(
    TrackingRefreshCodeRequested event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingRefreshCodeLoading());
    try {
      final result = await _repository.refreshCode(event.bidId);
      emit(TrackingConfirmCodeLoaded(result.code, expiresAt: result.expiresAt));
    } catch (e) {
      if (kDebugMode) debugPrint('[TrackingBloc] refreshCode error: $e');
      emit(TrackingRefreshCodeError(unwrapDioError(e)));
    }
  }

  Future<void> _onScanSubmit(
    QrScanSubmitRequested event,
    Emitter<TrackingState> emit,
  ) async {
    emit(QrScanSubmitting());
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline =
          connectivity.any((r) => r != ConnectivityResult.none);

      if (!isOnline) {
        await _offlineSync.queueScan(
          bidId: event.bidId,
          eventType: event.eventType,
          gpsLat: event.gpsLat,
          gpsLon: event.gpsLon,
          photoPath: event.photo?.path,
        );
        emit(QrScanQueued());
        return;
      }

      String? photoKey;
      if (event.photo != null) {
        photoKey = await _repository.uploadTrackingPhoto(
            event.bidId, event.photo!.path);
      }
      final result = await _repository.postScan(
        bidId: event.bidId,
        eventType: event.eventType,
        gpsLat: event.gpsLat,
        gpsLon: event.gpsLon,
        photoUrl: photoKey,
      );
      emit(QrScanSuccess(result));
      unawaited(_analytics.logEvent(
        AnalyticsEvents.qrScanSuccess,
        properties: {'scan_type': event.eventType, 'bid_id': event.bidId},
      ));
    } catch (e) {
      emit(QrScanError(unwrapDioError(e)));
    }
  }

  Future<void> _onConfirmDelivery(
    ConfirmDeliveryRequested event,
    Emitter<TrackingState> emit,
  ) async {
    emit(DeliveryConfirmLoading());
    try {
      final result = await _repository.confirmDelivery(
          bidId: event.bidId, code: event.code);
      emit(DeliveryConfirmSuccess(result));
    } catch (e) {
      if (kDebugMode) debugPrint('[TrackingBloc] confirmDelivery error: $e');
      emit(DeliveryConfirmError(unwrapDioError(e)));
    }
  }

  Future<void> _onOfflineSync(
    OfflineSyncRequested event,
    Emitter<TrackingState> emit,
  ) async {
    final before = _offlineSync.pendingCount;
    emit(OfflineSyncInProgress());
    await _offlineSync.syncAll();
    emit(OfflineSyncDone(before - _offlineSync.pendingCount));
  }
}
