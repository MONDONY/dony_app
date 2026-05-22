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
        deviceId: json['deviceId'] as String,
        deviceName: json['deviceName'] as String,
        platform: json['platform'] as String,
        lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
        isCurrent: json['isCurrent'] as bool,
      );
}
