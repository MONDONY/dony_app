class ProfilePublicModel {
  const ProfilePublicModel({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.kycVerified,
    required this.isProAccount,
    required this.isKiloPro,
    required this.completedBidsCount,
    required this.averageRating,
    required this.ratingCount,
    required this.memberSince,
    required this.badges,
    this.contactMode,
    this.responseDelayHours,
    this.bio,
    this.languages = const [],
    this.phoneVerified = false,
    this.emailVerified = false,
    this.residenceCountry,
    this.measuredResponseMinutes,
    this.lastSeenDaysAgo,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool kycVerified;
  final bool isProAccount;
  final bool isKiloPro;
  final int completedBidsCount;
  final double averageRating;
  final int ratingCount;
  final String memberSince;
  final List<String> badges;
  final String? contactMode;
  final int? responseDelayHours;
  final String? bio;
  final List<String> languages;

  /// Vérifications du compte (FLUTTER-4H). Booléens seulement : le serveur
  /// n'envoie jamais le numéro ni l'e-mail.
  final bool phoneVerified;
  final bool emailVerified;

  /// Code ISO2 du pays de résidence, présent seulement si l'utilisateur a
  /// choisi de l'afficher (filtré côté serveur).
  final String? residenceCountry;

  /// Temps de réponse mesuré (médiane, minutes) sur 90 jours ; nul sous trois
  /// décisions ou pour un back antérieur (FLUTTER-4H partie 2).
  final int? measuredResponseMinutes;

  /// Jours depuis la dernière ouverture de l'app (0 = aujourd'hui) ; nul si
  /// l'utilisateur la masque ou si elle est inconnue.
  final int? lastSeenDaysAgo;

  factory ProfilePublicModel.fromJson(Map<String, dynamic> json) {
    return ProfilePublicModel(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      kycVerified: json['kycVerified'] as bool? ?? false,
      isProAccount: json['isProAccount'] as bool? ?? false,
      isKiloPro: json['isKiloPro'] as bool? ?? false,
      completedBidsCount: json['completedBidsCount'] as int? ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['ratingCount'] as int? ?? 0,
      memberSince: json['memberSince'] as String? ?? '',
      badges:
          (json['badges'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      contactMode: json['contactMode'] as String?,
      responseDelayHours: json['responseDelayHours'] as int?,
      bio: json['bio'] as String?,
      languages:
          (json['languages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      emailVerified: json['emailVerified'] as bool? ?? false,
      residenceCountry: json['residenceCountry'] as String?,
      measuredResponseMinutes: (json['measuredResponseMinutes'] as num?)
          ?.toInt(),
      lastSeenDaysAgo: (json['lastSeenDaysAgo'] as num?)?.toInt(),
    );
  }
}
