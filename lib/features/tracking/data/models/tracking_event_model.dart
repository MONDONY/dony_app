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
      );

  String get stepLabel => switch (eventType) {
    'DEPART' => 'Départ confirmé',
    'TRANSIT' => 'En transit',
    'ARRIVEE' => 'Arrivée confirmée',
    _ => eventType,
  };

  String? get displayLocationLabel {
    final label = gpsLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    if (gpsLat != null && gpsLon != null) return 'Lieu GPS enregistré';
    return null;
  }
}
