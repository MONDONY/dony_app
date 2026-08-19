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

  /// Code ISO 3166-1 alpha-2, ou `null` tant que l'utilisateur ne l'a pas
  /// renseigné (état normal, complétable dans les Réglages). La devise est
  /// désormais dérivée du pays côté serveur : c'est ce champ, pas
  /// [currencyCode], qui est modifiable par le client.
  final String? country;

  /// Lecture seule, renvoyé par le serveur (gel au premier mouvement
  /// d'argent, même mécanisme que [currencyLocked]). Jamais envoyé dans
  /// [toJson].
  final bool countryLocked;

  const UserBusinessPrefsDto({
    required this.weightUnit,
    required this.currencyCode,
    required this.pickupRadiusKm,
    required this.defaultPackageWeightKg,
    required this.minBidPriceEur,
    this.contactMode,
    this.responseDelayHours,
    this.currencyLocked = false,
    this.country,
    this.countryLocked = false,
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
    String? country,
    bool? countryLocked,
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
    country: country ?? this.country,
    countryLocked: countryLocked ?? this.countryLocked,
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
        country: json['country'] as String?,
        countryLocked: json['countryLocked'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'weightUnit': weightUnit,
    'currencyCode': currencyCode,
    'pickupRadiusKm': pickupRadiusKm,
    'defaultPackageWeightKg': defaultPackageWeightKg,
    'minBidPriceEur': minBidPriceEur,
    if (contactMode != null) 'contactMode': contactMode,
    if (responseDelayHours != null) 'responseDelayHours': responseDelayHours,
    if (country != null) 'country': country,
  };
}
