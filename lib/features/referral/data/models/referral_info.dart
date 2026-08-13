class ReferralInfo {
  const ReferralInfo({
    required this.code,
    required this.shareUrl,
    required this.totalInvited,
    required this.signedUp,
    required this.rewarded,
    required this.totalEarnedCents,
    required this.hasBeenReferred,
    required this.currency,
    required this.rewardAmountCents,
  });

  final String code;
  final String shareUrl;
  final int totalInvited;
  final int signedUp;
  final int rewarded;
  final int totalEarnedCents;
  final bool hasBeenReferred;

  /// Devise du total gagné. Les récompenses sont versées dans la devise active
  /// du parrain au moment du versement : le serveur ne cumule donc que les
  /// crédits de cette devise, et c'est elle qu'il faut afficher.
  final String currency;

  /// Montant unitaire de la récompense, en unités mineures, tel que configuré
  /// côté serveur. Les libellés d'invitation annonçaient « 5 € » en dur, ce qui
  /// devenait faux dès que le parrain travaillait dans une autre devise.
  final int rewardAmountCents;

  factory ReferralInfo.fromJson(Map<String, dynamic> json) => ReferralInfo(
    code: json['code'] as String,
    shareUrl: json['shareUrl'] as String,
    totalInvited: json['totalInvited'] as int? ?? 0,
    signedUp: json['signedUp'] as int? ?? 0,
    rewarded: json['rewarded'] as int? ?? 0,
    totalEarnedCents: json['totalEarnedCents'] as int? ?? 0,
    hasBeenReferred: json['hasBeenReferred'] as bool? ?? false,
    // Repli euro pour rester compatible avec un backend antérieur à V203.
    currency: json['currency'] as String? ?? 'EUR',
    rewardAmountCents: json['rewardAmountCents'] as int? ?? 500,
  );
}
