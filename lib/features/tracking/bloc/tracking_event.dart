import 'package:dony/features/tracking/data/models/scan_method.dart';
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
  final String? gpsLabel;

  /// Provenance envoyée au back ; `null` : rien n'est envoyé.
  final ScanMethod? scanMethod;

  QrScanSubmitRequested({
    required this.bidId,
    required this.eventType,
    this.photo,
    this.gpsLat,
    this.gpsLon,
    this.gpsLabel,
    this.scanMethod,
  });
}

class ConfirmDeliveryRequested extends TrackingEvent {
  final String bidId;
  final String code;

  /// Photo de preuve de l'arrivée, uploadée avant la confirmation.
  final XFile? photo;

  /// Provenance envoyée au back ; `null` : rien n'est envoyé.
  final ScanMethod? scanMethod;

  ConfirmDeliveryRequested({
    required this.bidId,
    required this.code,
    this.photo,
    this.scanMethod,
  });
}

class TrackingRefreshCodeRequested extends TrackingEvent {
  final String bidId;
  TrackingRefreshCodeRequested(this.bidId);
}

class TrackingSetCodePublicVisibilityRequested extends TrackingEvent {
  final String bidId;
  final bool visible;

  TrackingSetCodePublicVisibilityRequested(this.bidId, {required this.visible});
}

class OfflineSyncRequested extends TrackingEvent {}
