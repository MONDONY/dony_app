/// Aperçu « Mon argent » (FLUTTER-HV) — contrat de `GET /payments/me/overview`
/// (yadony-back #481, #483, #484). Les champs nuls sont omis par le back
/// (`default-property-inclusion: NON_NULL`) : tout est optionnel à la lecture.
///
/// Le champ `wallet` de la réponse (soldes du portefeuille Yadony) n'est pas
/// lu : « Mon argent » ne suit que l'argent des colis, le solde Yadony reste
/// sur l'écran portefeuille.
library;

/// État normalisé d'un montant, calculé par le back.
enum MoneyState {
  escrowed,
  awaitingDeliveryConfirmation,
  releaseScheduled,
  inDispute,
  onHold,
  payoutInProgress,
  releasedRecently,
  refundPending,
  refundedRecently,
  cash,

  /// Valeur inconnue (back plus récent que l'app) : affichée sans frise.
  unknown;

  static MoneyState parse(String? value) => switch (value) {
    'ESCROWED' => escrowed, // i18n-ignore : code serveur
    'AWAITING_DELIVERY_CONFIRMATION' => awaitingDeliveryConfirmation,
    'RELEASE_SCHEDULED' => releaseScheduled,
    'IN_DISPUTE' => inDispute,
    'ON_HOLD' => onHold,
    'PAYOUT_IN_PROGRESS' => payoutInProgress,
    'RELEASED_RECENTLY' => releasedRecently,
    'REFUND_PENDING' => refundPending,
    'REFUNDED_RECENTLY' => refundedRecently,
    'CASH' => cash,
    _ => unknown,
  };
}

/// Condition (ou issue) de libération.
enum ReleaseCondition {
  onDeliveryConfirmation,
  autoReleaseAfterHoldIfNoDispute,
  adminDecision,
  adminReview,
  payoutProcessing,
  released,
  refundProcessing,
  refunded,
  cashInPerson,
  unknown;

  static ReleaseCondition parse(String? value) => switch (value) {
    'ON_DELIVERY_CONFIRMATION' => onDeliveryConfirmation,
    'AUTO_RELEASE_AFTER_HOLD_IF_NO_DISPUTE' => autoReleaseAfterHoldIfNoDispute,
    'ADMIN_DECISION' => adminDecision,
    'ADMIN_REVIEW' => adminReview,
    'PAYOUT_PROCESSING' => payoutProcessing,
    'RELEASED' => released,
    'REFUND_PROCESSING' => refundProcessing,
    'REFUNDED' => refunded,
    'CASH_IN_PERSON' => cashInPerson,
    _ => unknown,
  };
}

/// Côté de l'utilisateur sur le colis.
enum MoneyRole {
  traveler,
  sender;

  static MoneyRole parse(String? value) =>
      value == 'SENDER' ? sender : traveler; // i18n-ignore : code serveur
}

/// Moyen par lequel l'argent transite.
enum MoneyChannel {
  card,
  mobileMoney,
  cash;

  static MoneyChannel parse(String? value) => switch (value) {
    'MOBILE_MONEY' => mobileMoney,
    'CASH' => cash,
    _ => card,
  };
}

double? _toDouble(Object? v) => v is num ? v.toDouble() : null;

DateTime? _toDate(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// Un montant rattaché à un colis.
class MoneyItemModel {
  const MoneyItemModel({
    required this.bidId,
    required this.role,
    required this.state,
    required this.releaseCondition,
    required this.channel,
    this.trackingNumber,
    this.announcementId,
    this.departureCity,
    this.arrivalCity,
    this.departureDate,
    this.arrivalDate,
    this.amount,
    this.currency,
    this.releaseAt,
    this.settledAt,
    this.counterpartyName,
    this.bidStatus,
    this.weightKg,
    this.cashCommissionStatus,
  });

  final String bidId;
  final MoneyRole role;
  final MoneyState state;
  final ReleaseCondition releaseCondition;
  final MoneyChannel channel;
  final String? trackingNumber;
  final String? announcementId;
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? departureDate;

  /// Date d'arrivée effective du trajet (yadony-back #484) ; absente d'un
  /// back antérieur.
  final DateTime? arrivalDate;

  /// Échéance prévisible d'un séquestre versé à la livraison : l'arrivée du
  /// trajet, sinon (ancien back) le jour du départ.
  DateTime? get tripDate => arrivalDate ?? departureDate;

  /// Voyageur : net estimé. Expéditeur : payé moins déjà remboursé. `null`
  /// pour un colis en espèces.
  final double? amount;
  final String? currency;

  /// Date de libération automatique, seulement quand le back sait la calculer.
  final DateTime? releaseAt;

  /// Date de versement ou de remboursement déjà effectif.
  final DateTime? settledAt;

  /// Prénom + initiale de la contrepartie.
  final String? counterpartyName;

  /// Statut brut du colis (`ACCEPTED`, `HANDED_OVER`, `ARRIVED`…).
  final String? bidStatus;
  final double? weightKg;

  /// Espèces seulement : statut de la commission Yadony (`CHARGED`…).
  final String? cashCommissionStatus;

  factory MoneyItemModel.fromJson(Map<String, dynamic> json) {
    DateTime? day(Object? v) => v is String ? DateTime.tryParse(v) : null;
    return MoneyItemModel(
      bidId: json['bidId'] as String,
      role: MoneyRole.parse(json['role'] as String?),
      state: MoneyState.parse(json['state'] as String?),
      releaseCondition: ReleaseCondition.parse(
        json['releaseCondition'] as String?,
      ),
      channel: MoneyChannel.parse(json['channel'] as String?),
      trackingNumber: json['trackingNumber'] as String?,
      announcementId: json['announcementId'] as String?,
      departureCity: json['departureCity'] as String?,
      arrivalCity: json['arrivalCity'] as String?,
      departureDate: day(json['departureDate']),
      arrivalDate: day(json['arrivalDate']),
      amount: _toDouble(json['amount']),
      currency: json['currency'] as String?,
      releaseAt: _toDate(json['releaseAt']),
      settledAt: _toDate(json['settledAt']),
      counterpartyName: json['counterpartyName'] as String?,
      bidStatus: json['bidStatus'] as String?,
      weightKg: _toDouble(json['weightKg']),
      cashCommissionStatus: json['cashCommissionStatus'] as String?,
    );
  }

  /// Argent encore attendu par le voyageur (compte dans la pastille d'en-tête).
  bool get isUpcoming => switch (state) {
    MoneyState.escrowed ||
    MoneyState.awaitingDeliveryConfirmation ||
    MoneyState.releaseScheduled ||
    MoneyState.inDispute ||
    MoneyState.onHold ||
    MoneyState.payoutInProgress => true,
    _ => false,
  };
}

/// Montant dans une devise.
class MoneyAmount {
  const MoneyAmount(this.currency, this.amount);

  final String currency;
  final double amount;
}

/// Totaux voyageur d'une devise.
class TravelerTotalModel {
  const TravelerTotalModel({
    required this.currency,
    required this.upcoming,
    required this.releasedRecently,
  });

  final String currency;
  final double upcoming;
  final double releasedRecently;

  factory TravelerTotalModel.fromJson(Map<String, dynamic> json) =>
      TravelerTotalModel(
        currency: json['currency'] as String,
        upcoming: _toDouble(json['upcoming']) ?? 0,
        releasedRecently: _toDouble(json['releasedRecently']) ?? 0,
      );
}

/// Totaux expéditeur d'une devise.
class SenderTotalModel {
  const SenderTotalModel({
    required this.currency,
    required this.blocked,
    required this.refundPending,
    required this.refundedRecently,
  });

  final String currency;
  final double blocked;
  final double refundPending;
  final double refundedRecently;

  factory SenderTotalModel.fromJson(Map<String, dynamic> json) =>
      SenderTotalModel(
        currency: json['currency'] as String,
        blocked: _toDouble(json['blocked']) ?? 0,
        refundPending: _toDouble(json['refundPending']) ?? 0,
        refundedRecently: _toDouble(json['refundedRecently']) ?? 0,
      );
}

class MoneyOverviewModel {
  const MoneyOverviewModel({
    this.travelerTotals = const [],
    this.travelerItems = const [],
    this.senderTotals = const [],
    this.senderItems = const [],
    this.recentWindowDays = 30,
    this.activeCurrency,
    this.truncated = false,
  });

  final List<TravelerTotalModel> travelerTotals;
  final List<MoneyItemModel> travelerItems;
  final List<SenderTotalModel> senderTotals;
  final List<MoneyItemModel> senderItems;
  final int recentWindowDays;

  /// Devise active de l'utilisateur (yadony-back #483) : mise en tête quand
  /// un montant existe dans plusieurs devises. Optionnelle.
  final String? activeCurrency;

  /// Le back a coupé la liste à son plafond (yadony-back #484) : les totaux
  /// ne portent que sur les colis renvoyés.
  final bool truncated;

  factory MoneyOverviewModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(Object? v) =>
        ((v as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>();
    final traveler = (json['traveler'] as Map<String, dynamic>?) ?? const {};
    final sender = (json['sender'] as Map<String, dynamic>?) ?? const {};
    return MoneyOverviewModel(
      travelerTotals: list(
        traveler['totals'],
      ).map(TravelerTotalModel.fromJson).toList(),
      travelerItems: list(
        traveler['items'],
      ).map(MoneyItemModel.fromJson).toList(),
      senderTotals: list(
        sender['totals'],
      ).map(SenderTotalModel.fromJson).toList(),
      senderItems: list(sender['items']).map(MoneyItemModel.fromJson).toList(),
      recentWindowDays: (json['recentWindowDays'] as num?)?.toInt() ?? 30,
      activeCurrency: switch (json['activeCurrency']) {
        final String code when code.trim().isNotEmpty =>
          code.trim().toUpperCase(),
        _ => null,
      },
      truncated: json['truncated'] == true,
    );
  }

  /// Montants voyageur à venir non nuls, par devise.
  List<MoneyAmount> get travelerUpcoming => [
    for (final t in travelerTotals)
      if (t.upcoming > 0) MoneyAmount(t.currency, t.upcoming),
  ];

  /// Montants expéditeur bloqués non nuls, par devise.
  List<MoneyAmount> get senderBlocked => [
    for (final t in senderTotals)
      if (t.blocked > 0) MoneyAmount(t.currency, t.blocked),
  ];

  int get travelerUpcomingCount =>
      travelerItems.where((i) => i.isUpcoming).length;

  int get senderBlockedCount => senderItems
      .where(
        (i) =>
            i.isUpcoming &&
            i.state != MoneyState.payoutInProgress &&
            i.state != MoneyState.unknown,
      )
      .length;

  bool get isEmpty => travelerItems.isEmpty && senderItems.isEmpty;
}
