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
    this.firstDelivery,
    this.pendingRewardCount,
    this.rewardWalletAmount,
    this.rewardWalletCurrency,
    this.rewardDiscountPercent,
  });

  /// Barème de repli quand le back ne publie pas encore la récompense au
  /// choix (yadony-back antérieur à #528) : 5 € ou -5 %.
  static const defaultRewardWalletAmount = 5.0;
  static const defaultRewardWalletCurrency = 'EUR';
  static const defaultRewardDiscountPercent = 5;

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

  /// Filleuls dont le premier envoi a été livré. `null` sur un back
  /// antérieur à #528 : l'écran retombe alors sur [rewarded].
  final int? firstDelivery;

  /// Récompenses débloquées et pas encore choisies (`null` sur un ancien back).
  final int? pendingRewardCount;

  /// Montant de la récompense « crédit sur le solde » (5.00).
  final double? rewardWalletAmount;
  final String? rewardWalletCurrency;

  /// Pourcentage de la récompense « code de réduction » (5).
  final int? rewardDiscountPercent;

  /// Barème effectif, avec repli sur 5 € / 5 % : la promesse de l'écran ne
  /// disparaît jamais, même sur un back qui ne la publie pas encore.
  double get effectiveRewardWalletAmount =>
      rewardWalletAmount ?? defaultRewardWalletAmount;
  String get effectiveRewardWalletCurrency =>
      rewardWalletCurrency ?? defaultRewardWalletCurrency;
  int get effectiveRewardDiscountPercent =>
      rewardDiscountPercent ?? defaultRewardDiscountPercent;

  /// Compteur « 1er envoi fait ».
  int get firstDeliveryCount => firstDelivery ?? rewarded;

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
    firstDelivery: (json['firstDelivery'] as num?)?.toInt(),
    pendingRewardCount: (json['pendingRewardCount'] as num?)?.toInt(),
    rewardWalletAmount: (json['rewardWalletAmount'] as num?)?.toDouble(),
    rewardWalletCurrency: json['rewardWalletCurrency'] as String?,
    rewardDiscountPercent: (json['rewardDiscountPercent'] as num?)?.round(),
  );
}
