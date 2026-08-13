class DeviceModel {
  final String deviceId;
  final String deviceName;
  final String platform;
  final DateTime lastSeenAt;
  final bool isCurrent;

  const DeviceModel({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.lastSeenAt,
    required this.isCurrent,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
    deviceId: json['deviceId'] as String? ?? '',
    deviceName: json['deviceName'] as String? ?? 'Appareil inconnu',
    platform: json['platform'] as String? ?? 'android',
    lastSeenAt:
        DateTime.tryParse(json['lastSeenAt'] as String? ?? '') ??
        DateTime.now(),
    isCurrent: json['isCurrent'] as bool? ?? false,
  );
}
