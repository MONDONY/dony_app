class UserBusinessPrefsDto {
  final String weightUnit;
  final String currencyCode;
  final int pickupRadiusKm;
  final int defaultPackageWeightKg;
  final int minBidPriceEur;
  final String? contactMode;
  final int? responseDelayHours;

  /// Lecture seule, renvoyé par le serveur (lot 2 : gel au premier mouvement
  /// d'argent). Jamais envoyé dans [toJson] — le serveur l'ignorerait de
  /// toute façon, mais un champ qu'on ne lit jamais côté écriture ne doit pas
  /// prétendre pouvoir être modifié par le client.
  final bool currencyLocked;

  const UserBusinessPrefsDto({
    required this.weightUnit,
    required this.currencyCode,
    required this.pickupRadiusKm,
    required this.defaultPackageWeightKg,
    required this.minBidPriceEur,
    this.contactMode,
    this.responseDelayHours,
    this.currencyLocked = false,
  });

  /// Recopier les champs un à un sur les sites d'appel fait perdre en silence
  /// tout champ ajouté ici par la suite : le PUT réécrirait l'ancienne valeur.
  UserBusinessPrefsDto copyWith({
    String? weightUnit,
    String? currencyCode,
    int? pickupRadiusKm,
    int? defaultPackageWeightKg,
    int? minBidPriceEur,
    String? contactMode,
    int? responseDelayHours,
    bool? currencyLocked,
  }) => UserBusinessPrefsDto(
    weightUnit: weightUnit ?? this.weightUnit,
    currencyCode: currencyCode ?? this.currencyCode,
    pickupRadiusKm: pickupRadiusKm ?? this.pickupRadiusKm,
    defaultPackageWeightKg:
        defaultPackageWeightKg ?? this.defaultPackageWeightKg,
    minBidPriceEur: minBidPriceEur ?? this.minBidPriceEur,
    contactMode: contactMode ?? this.contactMode,
    responseDelayHours: responseDelayHours ?? this.responseDelayHours,
    currencyLocked: currencyLocked ?? this.currencyLocked,
  );

  factory UserBusinessPrefsDto.fromJson(Map<String, dynamic> json) =>
      UserBusinessPrefsDto(
        weightUnit: json['weightUnit'] as String? ?? 'kg',
        currencyCode: json['currencyCode'] as String? ?? 'EUR',
        pickupRadiusKm: json['pickupRadiusKm'] as int? ?? 10,
        defaultPackageWeightKg: json['defaultPackageWeightKg'] as int? ?? 23,
        minBidPriceEur: json['minBidPriceEur'] as int? ?? 0,
        contactMode: json['contactMode'] as String?,
        responseDelayHours: json['responseDelayHours'] as int?,
        currencyLocked: json['currencyLocked'] as bool? ?? false,
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
