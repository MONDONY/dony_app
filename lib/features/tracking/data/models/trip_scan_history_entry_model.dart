import 'package:dony/features/tracking/data/models/scan_method.dart';

class TripScanHistoryEntryModel {
  final String? donNumber;
  final String? recipientName;
  final String eventType;
  final DateTime scannedAt;

  /// Provenance du scan, `null` si le back ne la connaît pas.
  final ScanMethod? scanMethod;

  const TripScanHistoryEntryModel({
    this.donNumber,
    this.recipientName,
    required this.eventType,
    required this.scannedAt,
    this.scanMethod,
  });

  factory TripScanHistoryEntryModel.fromJson(Map<String, dynamic> json) =>
      TripScanHistoryEntryModel(
        donNumber: json['donNumber'] as String?,
        recipientName: json['recipientName'] as String?,
        eventType: json['eventType'] as String,
        scannedAt: DateTime.parse(json['scannedAt'] as String),
        scanMethod: ScanMethod.fromWire(json['scanMethod']),
      );
}
