import 'package:image_picker/image_picker.dart';

abstract class TrackingEvent {}

class TrackingQrCodeRequested extends TrackingEvent {
  final String bidId;
  TrackingQrCodeRequested(this.bidId);
}

class TrackingSearchRequested extends TrackingEvent {
  final String number;
  TrackingSearchRequested(this.number);
}

class TrackingEventsRequested extends TrackingEvent {
  final String bidId;
  TrackingEventsRequested(this.bidId);
}

class QrScanSubmitRequested extends TrackingEvent {
  final String bidId;
  final String eventType;
  final XFile? photo;
  final double? gpsLat;
  final double? gpsLon;

  QrScanSubmitRequested({
    required this.bidId,
    required this.eventType,
    this.photo,
    this.gpsLat,
    this.gpsLon,
  });
}

class OfflineSyncRequested extends TrackingEvent {}
