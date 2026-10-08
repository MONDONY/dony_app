import 'dart:async';

import 'package:dony/core/error/app_exception.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/features/tracking/bloc/tracking_event.dart';
import 'package:dony/features/tracking/bloc/tracking_state.dart';
import 'package:dony/features/tracking/data/offline_sync_service.dart';
import 'package:dony/features/tracking/data/scan_submitter.dart';
import 'package:dony/features/tracking/data/tracking_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  final TrackingRepository _repository;
  final OfflineSyncService _offlineSync;
  final AnalyticsService _analytics;
  final ScanSubmitter _submitter;

  TrackingBloc(
    this._repository,
    this._offlineSync,
    this._analytics, {
    ScanSubmitter? submitter,
  }) : _submitter = submitter ?? ScanSubmitter(_repository, _offlineSync),
       super(TrackingInitial()) {
    on<TrackingQrCodeRequested>(_onQrCodeRequested);
    on<TrackingSearchRequested>(_onSearchRequested);
    on<TrackingEventsRequested>(_onEventsRequested);
    on<TrackingRefreshCodeRequested>(_onRefreshCodeRequested);
    on<TrackingSetCodePublicVisibilityRequested>(
      _onSetCodePublicVisibilityRequested,
    );
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

  Future<void> _onRefreshCodeRequested(
    TrackingRefreshCodeRequested event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingRefreshCodeLoading());
    try {
      final result = await _repository.refreshCode(event.bidId);
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.pickupCodeRegenerated,
          properties: {'after_block': event.afterBlock},
        ),
      );
      emit(
        TrackingConfirmCodeLoaded(
          result.code,
          expiresAt: result.expiresAt,
          publicPageVisible: result.publicPageVisible,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[TrackingBloc] refreshCode error: $e');
      emit(TrackingRefreshCodeError(unwrapDioError(e)));
    }
  }

  Future<void> _onSetCodePublicVisibilityRequested(
    TrackingSetCodePublicVisibilityRequested event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingConfirmCodePublicVisibilityLoading());
    try {
      final result = await _repository.setConfirmationCodePublicVisible(
        event.bidId,
        visible: event.visible,
      );
      emit(
        TrackingConfirmCodeLoaded(
          result.code,
          expiresAt: result.expiresAt,
          publicPageVisible: result.publicPageVisible,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TrackingBloc] set public code visibility error: $e');
      }
      emit(TrackingRefreshCodeError(unwrapDioError(e)));
    }
  }

  Future<void> _onScanSubmit(
    QrScanSubmitRequested event,
    Emitter<TrackingState> emit,
  ) async {
    emit(QrScanSubmitting());
    try {
      final result = await _submitter.submit(
        bidId: event.bidId,
        eventType: event.eventType,
        photoPath: event.photo?.path,
        gpsLat: event.gpsLat,
        gpsLon: event.gpsLon,
        gpsLabel: event.gpsLabel,
        scanMethod: event.scanMethod,
        trackingNumber: event.trackingNumber,
      );
      if (result is! ScanSubmitSent) {
        emit(QrScanQueued());
        return;
      }
      emit(QrScanSuccess(result.event));
      unawaited(
        _analytics.logEvent(
          AnalyticsEvents.qrScanSuccess,
          properties: {'scan_type': event.eventType, 'bid_id': event.bidId},
        ),
      );
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
      String? photoKey;
      if (event.photo != null) {
        photoKey = await _repository.uploadTrackingPhoto(
          event.bidId,
          event.photo!.path,
        );
      }
      final result = await _repository.confirmDelivery(
        bidId: event.bidId,
        code: event.code,
        photoUrl: photoKey,
        scanMethod: event.scanMethod,
        gpsLat: event.gpsLat,
        gpsLon: event.gpsLon,
        gpsLabel: event.gpsLabel,
      );
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
