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

  /// [deviceName] garde `''` quand le serveur ne renvoie rien : c'est
  /// l'écran qui affiche le libellé traduit `devicesUnknown` pour un nom
  /// vide, jamais ce modèle qui n'a pas accès à `AppLocalizations`.
  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
    deviceId: json['deviceId'] as String? ?? '',
    deviceName: json['deviceName'] as String? ?? '',
    platform: json['platform'] as String? ?? 'android',
    lastSeenAt:
        DateTime.tryParse(json['lastSeenAt'] as String? ?? '') ??
        DateTime.now(),
    isCurrent: json['isCurrent'] as bool? ?? false,
  );
}
