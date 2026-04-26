import 'package:dony/features/tracking/data/models/qr_code_model.dart';
import 'package:dony/features/tracking/data/models/tracking_event_model.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';

abstract class TrackingState {}

class TrackingInitial extends TrackingState {}

// QR code display
class TrackingQrLoading extends TrackingState {}

class TrackingQrLoaded extends TrackingState {
  final QrCodeModel qrCode;
  TrackingQrLoaded(this.qrCode);
}

class TrackingQrError extends TrackingState {
  final String message;
  TrackingQrError(this.message);
}

// Tracking number search
class TrackingSearchLoading extends TrackingState {}

class TrackingSearchLoaded extends TrackingState {
  final TrackingSearchModel result;
  TrackingSearchLoaded(this.result);
}

class TrackingSearchError extends TrackingState {
  final String message;
  TrackingSearchError(this.message);
}

// Events timeline
class TrackingEventsLoading extends TrackingState {}

class TrackingEventsLoaded extends TrackingState {
  final List<TrackingEventModel> events;
  TrackingEventsLoaded(this.events);
}

class TrackingEventsError extends TrackingState {
  final String message;
  TrackingEventsError(this.message);
}

// Confirmation code (sender side)
class TrackingConfirmCodeLoading extends TrackingState {}

class TrackingConfirmCodeLoaded extends TrackingState {
  final String? code;
  TrackingConfirmCodeLoaded(this.code);
}

class TrackingConfirmCodeError extends TrackingState {}

// QR scan submission
class QrScanSubmitting extends TrackingState {}

class QrScanSuccess extends TrackingState {
  final TrackingEventModel event;
  QrScanSuccess(this.event);
}

class QrScanQueued extends TrackingState {}

class QrScanError extends TrackingState {
  final String message;
  QrScanError(this.message);
}

// Delivery confirmation (traveler side)
class DeliveryConfirmLoading extends TrackingState {}

class DeliveryConfirmSuccess extends TrackingState {
  final TrackingEventModel event;
  DeliveryConfirmSuccess(this.event);
}

class DeliveryConfirmError extends TrackingState {
  final String message;
  DeliveryConfirmError(this.message);
}

// Offline sync
class OfflineSyncInProgress extends TrackingState {}

class OfflineSyncDone extends TrackingState {
  final int synced;
  OfflineSyncDone(this.synced);
}
