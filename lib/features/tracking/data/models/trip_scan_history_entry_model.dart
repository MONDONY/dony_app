class TripScanHistoryEntryModel {
  final String? donNumber;
  final String? recipientName;
  final String eventType;
  final DateTime scannedAt;

  const TripScanHistoryEntryModel({
    this.donNumber,
    this.recipientName,
    required this.eventType,
    required this.scannedAt,
  });

  factory TripScanHistoryEntryModel.fromJson(Map<String, dynamic> json) =>
      TripScanHistoryEntryModel(
        donNumber: json['donNumber'] as String?,
        recipientName: json['recipientName'] as String?,
        eventType: json['eventType'] as String,
        scannedAt: DateTime.parse(json['scannedAt'] as String),
      );
}
