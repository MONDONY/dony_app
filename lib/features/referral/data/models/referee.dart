/// Récompense qu'un parrain choisit pour un filleul qui a fait son premier
/// envoi (yadony-back #528).
///
/// `commissionVoucher` est l'ancien bon de commission (-50 %), attribué
/// automatiquement avant le choix : il n'est jamais proposé dans la feuille de
/// choix, seulement relu pour l'historique.
enum RewardChoice {
  walletCredit('WALLET_CREDIT'),
  discountCode('DISCOUNT_CODE'),
  commissionVoucher('COMMISSION_VOUCHER');

  const RewardChoice(this.wire);

  /// Valeur échangée avec le back, et propriété analytics `choice`.
  final String wire;

  static RewardChoice? fromWire(Object? value) {
    for (final choice in values) {
      if (choice.wire == value) return choice;
    }
    return null;
  }
}

/// Avancement d'un filleul : inscrit, premier envoi livré, récompensé.
enum RefereeStatus {
  signedUp,
  firstDelivery,
  rewarded;

  static RefereeStatus fromWire(Object? value) => switch (value) {
    'FIRST_DELIVERY' => firstDelivery,
    'REWARDED' => rewarded,
    _ => signedUp,
  };
}

/// État de la récompense liée à un filleul.
enum RewardStatus {
  none,
  available,
  chosen;

  static RewardStatus fromWire(Object? value) => switch (value) {
    'AVAILABLE' => available,
    'CHOSEN' => chosen,
    _ => none,
  };
}

/// Code de réduction personnel obtenu en récompense.
class RefereeDiscountCode {
  const RefereeDiscountCode({
    required this.code,
    required this.percent,
    this.expiresAt,
    this.used = false,
    this.expired = false,
  });

  final String code;
  final int percent;
  final DateTime? expiresAt;
  final bool used;
  final bool expired;

  /// `null` si la réponse ne porte pas de code exploitable (champ absent ou
  /// vide) : l'écran n'affiche alors pas de code inventé.
  static RefereeDiscountCode? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final code = json['code'];
    if (code is! String || code.isEmpty) return null;
    return RefereeDiscountCode(
      code: code,
      percent: (json['percent'] as num?)?.round() ?? 0,
      expiresAt: _parseDate(json['expiresAt']),
      used: json['used'] as bool? ?? false,
      expired: json['expired'] as bool? ?? false,
    );
  }
}

/// Un filleul vu par son parrain (`GET /me/referral/referees`).
class Referee {
  const Referee({
    required this.invitationId,
    this.displayName,
    this.signedUpAt,
    this.status = RefereeStatus.signedUp,
    this.rewardStatus = RewardStatus.none,
    this.rewardChoice,
    this.rewardAvailableAt,
    this.rewardChosenAt,
    this.walletAmount,
    this.walletCurrency,
    this.discountCode,
  });

  final String invitationId;

  /// « Awa D. » ; `null` quand le filleul n'a pas encore de nom affichable.
  final String? displayName;
  final DateTime? signedUpAt;
  final RefereeStatus status;
  final RewardStatus rewardStatus;
  final RewardChoice? rewardChoice;
  final DateTime? rewardAvailableAt;
  final DateTime? rewardChosenAt;

  /// Montant crédité sur le solde quand le choix est `WALLET_CREDIT`.
  final double? walletAmount;
  final String? walletCurrency;
  final RefereeDiscountCode? discountCode;

  bool get isRewardAvailable => rewardStatus == RewardStatus.available;

  /// Crédit wallet effectivement obtenu pour ce filleul, 0 sinon.
  double get earnedWalletAmount =>
      rewardStatus == RewardStatus.chosen &&
          rewardChoice == RewardChoice.walletCredit
      ? (walletAmount ?? 0)
      : 0;

  /// Initiales du nom affiché (« Awa D. » → « AD »), `null` sans nom.
  String? get initials {
    final name = displayName?.trim();
    if (name == null || name.isEmpty) return null;
    final letters = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => String.fromCharCode(part.runes.first).toUpperCase())
        .join();
    return letters.isEmpty ? null : letters;
  }

  factory Referee.fromJson(Map<String, dynamic> json) => Referee(
    invitationId: json['invitationId'] as String,
    displayName: _nonBlank(json['displayName']),
    signedUpAt: _parseDate(json['signedUpAt']),
    status: RefereeStatus.fromWire(json['status']),
    rewardStatus: RewardStatus.fromWire(json['rewardStatus']),
    rewardChoice: RewardChoice.fromWire(json['rewardChoice']),
    rewardAvailableAt: _parseDate(json['rewardAvailableAt']),
    rewardChosenAt: _parseDate(json['rewardChosenAt']),
    walletAmount: (json['walletAmount'] as num?)?.toDouble(),
    walletCurrency: json['walletCurrency'] as String?,
    discountCode: RefereeDiscountCode.tryParse(json['discountCode']),
  );
}

/// Une page de filleuls (`PageResponse` du back).
class RefereePage {
  const RefereePage({
    required this.content,
    required this.page,
    required this.last,
    this.totalElements = 0,
  });

  final List<Referee> content;
  final int page;
  final bool last;
  final int totalElements;

  factory RefereePage.fromJson(Map<String, dynamic> json) {
    final items = (json['content'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Referee.fromJson)
        .toList();
    return RefereePage(
      content: items,
      page: (json['page'] as num?)?.toInt() ?? 0,
      last: json['last'] as bool? ?? true,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? items.length,
    );
  }
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String? _nonBlank(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
