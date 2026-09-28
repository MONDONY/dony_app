import 'package:dony/features/tracking/data/models/scan_method.dart';

class TrackingEventModel {
  final String id;
  final String bidId;
  final String eventType;
  final DateTime scannedAt;
  final double? gpsLat;
  final double? gpsLon;
  final String? gpsLabel;
  final String? photoUrl;
  final DateTime? offlineTimestamp;
  final DateTime createdAt;

  /// Provenance de l'étape, `null` si le back ne la connaît pas.
  final ScanMethod? scanMethod;

  const TrackingEventModel({
    required this.id,
    required this.bidId,
    required this.eventType,
    required this.scannedAt,
    this.gpsLat,
    this.gpsLon,
    this.gpsLabel,
    this.photoUrl,
    this.offlineTimestamp,
    required this.createdAt,
    this.scanMethod,
  });

  factory TrackingEventModel.fromJson(Map<String, dynamic> json) =>
      TrackingEventModel(
        id: json['id'] as String,
        bidId: json['bidId'] as String,
        eventType: json['eventType'] as String,
        scannedAt: DateTime.parse(json['scannedAt'] as String),
        gpsLat: (json['gpsLat'] as num?)?.toDouble(),
        gpsLon: (json['gpsLon'] as num?)?.toDouble(),
        gpsLabel: json['gpsLabel'] as String?,
        photoUrl: json['photoUrl'] as String?,
        offlineTimestamp: json['offlineTimestamp'] == null
            ? null
            : DateTime.parse(json['offlineTimestamp'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        scanMethod: ScanMethod.fromWire(json['scanMethod']),
      );
}
