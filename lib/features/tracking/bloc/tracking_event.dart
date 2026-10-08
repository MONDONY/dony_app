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

  /// Numéro de suivi saisi à la remise du colis (DEPART).
  final String? trackingNumber;

  QrScanSubmitRequested({
    required this.bidId,
    required this.eventType,
    this.photo,
    this.gpsLat,
    this.gpsLon,
    this.gpsLabel,
    this.scanMethod,
    this.trackingNumber,
  });
}

class ConfirmDeliveryRequested extends TrackingEvent {
  final String bidId;
  final String code;

  /// Photo de preuve de l'arrivée, uploadée avant la confirmation.
  final XFile? photo;

  /// Provenance envoyée au back ; `null` : rien n'est envoyé.
  final ScanMethod? scanMethod;

  /// Position relevée à l'arrivée, comme pour les autres étapes. Elle
  /// n'était pas transmise : l'arrivée n'avait jamais de lieu (FLUTTER-2A).
  final double? gpsLat;
  final double? gpsLon;
  final String? gpsLabel;

  ConfirmDeliveryRequested({
    required this.bidId,
    required this.code,
    this.photo,
    this.scanMethod,
    this.gpsLat,
    this.gpsLon,
    this.gpsLabel,
  });
}

class TrackingRefreshCodeRequested extends TrackingEvent {
  final String bidId;

  /// Régénération depuis le talon « Code de retrait bloqué » (FLUTTER-G1) :
  /// le code précédent a été effacé après trop d'essais ou à l'expiration.
  final bool afterBlock;

  TrackingRefreshCodeRequested(this.bidId, {this.afterBlock = false});
}

class TrackingSetCodePublicVisibilityRequested extends TrackingEvent {
  final String bidId;
  final bool visible;

  TrackingSetCodePublicVisibilityRequested(this.bidId, {required this.visible});
}

class OfflineSyncRequested extends TrackingEvent {}
