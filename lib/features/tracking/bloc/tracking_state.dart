import 'package:dony/features/tracking/data/models/qr_code_model.dart';
import 'package:dony/features/tracking/data/models/tracking_search_model.dart';

abstract class TrackingState {}

class TrackingInitial extends TrackingState {}

class TrackingQrLoading extends TrackingState {}

class TrackingQrLoaded extends TrackingState {
  final QrCodeModel qrCode;
  TrackingQrLoaded(this.qrCode);
}

class TrackingQrError extends TrackingState {
  final String message;
  TrackingQrError(this.message);
}

class TrackingSearchLoading extends TrackingState {}

class TrackingSearchLoaded extends TrackingState {
  final TrackingSearchModel result;
  TrackingSearchLoaded(this.result);
}

class TrackingSearchError extends TrackingState {
  final String message;
  TrackingSearchError(this.message);
}
