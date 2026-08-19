class ReferralInfo {
  const ReferralInfo({
    required this.code,
    required this.shareUrl,
    required this.totalInvited,
    required this.signedUp,
    required this.rewarded,
    required this.hasBeenReferred,
    required this.activeVoucherCount,
    this.voucherFactor,
    this.nextVoucherExpiresAt,
  });

  final String code;
  final String shareUrl;
  final int totalInvited;
  final int signedUp;
  final int rewarded;
  final bool hasBeenReferred;

  /// Nombre de bons octroyés et pas encore consommés ni expirés.
  final int activeVoucherCount;

  /// Facteur multiplicatif appliqué par un bon (0.50 = moitié prix), tel que
  /// configuré côté serveur. Toujours renseigné (barème courant) même sans bon
  /// actif — c'est la promesse faite au prochain parrainage, pas une propriété
  /// d'un bon en particulier. `null` uniquement en repli défensif (backend
  /// antérieur au lot 3 ou champ absent).
  final double? voucherFactor;

  /// Expiration du bon actif le plus proche, `null` si aucun bon actif.
  final DateTime? nextVoucherExpiresAt;

  /// Réduction en pourcentage entier (50 pour un facteur 0.50), ou `null` si
  /// aucun bon actif. Calculée ici pour que l'écran n'ait jamais à refaire
  /// l'arithmétique lui-même.
  int? get voucherPercentOff =>
      voucherFactor == null ? null : ((1 - voucherFactor!) * 100).round();

  factory ReferralInfo.fromJson(Map<String, dynamic> json) => ReferralInfo(
    code: json['code'] as String,
    shareUrl: json['shareUrl'] as String,
    totalInvited: json['totalInvited'] as int? ?? 0,
    signedUp: json['signedUp'] as int? ?? 0,
    rewarded: json['rewarded'] as int? ?? 0,
    hasBeenReferred: json['hasBeenReferred'] as bool? ?? false,
    activeVoucherCount: json['activeVoucherCount'] as int? ?? 0,
    voucherFactor: (json['voucherFactor'] as num?)?.toDouble(),
    nextVoucherExpiresAt: json['nextVoucherExpiresAt'] == null
        ? null
        : DateTime.parse(json['nextVoucherExpiresAt'] as String),
  );
}
