class UserBusinessPrefsDto {
  final String weightUnit;
  final String currencyCode;
  final int pickupRadiusKm;
  final int defaultPackageWeightKg;
  final int minBidPriceEur;
  final String? contactMode;
  final int? responseDelayHours;

  const UserBusinessPrefsDto({
    required this.weightUnit,
    required this.currencyCode,
    required this.pickupRadiusKm,
    required this.defaultPackageWeightKg,
    required this.minBidPriceEur,
    this.contactMode,
    this.responseDelayHours,
  });

  factory UserBusinessPrefsDto.fromJson(Map<String, dynamic> json) =>
      UserBusinessPrefsDto(
        weightUnit: json['weightUnit'] as String? ?? 'kg',
        currencyCode: json['currencyCode'] as String? ?? 'EUR',
        pickupRadiusKm: json['pickupRadiusKm'] as int? ?? 10,
        defaultPackageWeightKg: json['defaultPackageWeightKg'] as int? ?? 23,
        minBidPriceEur: json['minBidPriceEur'] as int? ?? 0,
        contactMode: json['contactMode'] as String?,
        responseDelayHours: json['responseDelayHours'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'weightUnit': weightUnit,
        'currencyCode': currencyCode,
        'pickupRadiusKm': pickupRadiusKm,
        'defaultPackageWeightKg': defaultPackageWeightKg,
        'minBidPriceEur': minBidPriceEur,
        if (contactMode != null) 'contactMode': contactMode,
        if (responseDelayHours != null) 'responseDelayHours': responseDelayHours,
      };
}
