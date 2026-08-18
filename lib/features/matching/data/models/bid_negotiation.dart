// Modèles du fil de négociation du prix d'un trajet.
//
// Parsing manuel, comme `AnnouncementGridItemModel` : ces classes ne sont
// jamais sérialisées vers le serveur (les corps de requête sont construits
// dans le datasource), un aller-retour build_runner n'apporterait rien.

/// Type d'un message du fil.
///
/// Le repli sur [proposal] couvre un futur type inconnu envoyé par un backend
/// plus récent : un fil doit rester lisible plutôt que de lever.
enum BidNegotiationMessageKind { proposal, counter, accept, reject }

BidNegotiationMessageKind bidNegotiationMessageKindFromWire(String? wire) {
  switch (wire) {
    case 'COUNTER':
      return BidNegotiationMessageKind.counter;
    case 'ACCEPT':
      return BidNegotiationMessageKind.accept;
    case 'REJECT':
      return BidNegotiationMessageKind.reject;
    default:
      return BidNegotiationMessageKind.proposal;
  }
}

double? _asDouble(Object? value) => (value as num?)?.toDouble();

DateTime? _asDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

/// Article hors grille : décrit ET chiffré par l'expéditeur. C'est ce que le
/// voyageur n'a jamais tarifé, donc ce qui justifie la négociation.
class BidCustomItem {
  final String id;
  final String label;
  final int quantity;
  final double amountEur;

  const BidCustomItem({
    required this.id,
    required this.label,
    required this.quantity,
    required this.amountEur,
  });

  factory BidCustomItem.fromJson(Map<String, dynamic> json) => BidCustomItem(
    id: json['id'] as String,
    label: json['label'] as String,
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    amountEur: _asDouble(json['amountEur']) ?? 0,
  );

  double get totalEur => amountEur * quantity;
}

/// Ligne de grille telle qu'affichée dans le fil. Le prix porté est le prix
/// EXPÉDITEUR (commission incluse), jamais le net voyageur.
class BidGridLine {
  final String id;
  final String label;
  final double unitPriceDisplayEur;
  final int quantity;

  const BidGridLine({
    required this.id,
    required this.label,
    required this.unitPriceDisplayEur,
    required this.quantity,
  });

  factory BidGridLine.fromJson(Map<String, dynamic> json) => BidGridLine(
    id: json['id'] as String,
    label: json['label'] as String,
    unitPriceDisplayEur: _asDouble(json['unitPriceDisplayEur']) ?? 0,
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
  );

  double get totalEur => unitPriceDisplayEur * quantity;
}

/// Un message du fil : une proposition, une contre-offre, une acceptation ou
/// un refus.
class BidNegotiationMessage {
  final String id;
  final BidNegotiationMessageKind kind;
  final String authorId;

  /// Montant porté par le message. Nul sur un ACCEPT / REJECT.
  final double? proposedGrossEur;
  final String? body;
  final DateTime? createdAt;

  const BidNegotiationMessage({
    required this.id,
    required this.kind,
    required this.authorId,
    this.proposedGrossEur,
    this.body,
    this.createdAt,
  });

  factory BidNegotiationMessage.fromJson(Map<String, dynamic> json) =>
      BidNegotiationMessage(
        id: json['id'] as String,
        kind: bidNegotiationMessageKindFromWire(json['kind'] as String?),
        authorId: json['authorId'] as String,
        proposedGrossEur: _asDouble(json['proposedGrossEur']),
        body: json['body'] as String?,
        createdAt: _asDate(json['createdAt']),
      );
}

/// Fil complet d'une négociation de prix.
///
/// [netEur] et [commissionEur] ne sont renseignés que selon le rôle : le
/// backend décide de la vue, le client ne recalcule rien.
class BidNegotiation {
  final String bidId;
  final String announcementId;
  final String status;
  final int round;
  final int maxRounds;
  final bool myTurn;
  final bool canCounter;
  final String currency;
  final double proposedGrossEur;
  final double? netEur;
  final double? commissionEur;
  final double? suggestedGrossEur;
  final double? weightKg;
  final String? description;
  final String? contentCategory;
  final List<BidGridLine> gridItems;
  final List<BidCustomItem> customItems;
  final List<String> photoUrls;
  final String? counterpartyName;
  final String? departureCity;
  final String? arrivalCity;

  /// Date seule (`yyyy-MM-dd`), pas un instant.
  final DateTime? departureDate;
  final DateTime? expiresAt;
  final List<BidNegotiationMessage> messages;

  const BidNegotiation({
    required this.bidId,
    required this.announcementId,
    required this.status,
    this.round = 0,
    this.maxRounds = 0,
    this.myTurn = false,
    this.canCounter = false,
    this.currency = 'EUR',
    this.proposedGrossEur = 0,
    this.netEur,
    this.commissionEur,
    this.suggestedGrossEur,
    this.weightKg,
    this.description,
    this.contentCategory,
    this.gridItems = const [],
    this.customItems = const [],
    this.photoUrls = const [],
    this.counterpartyName,
    this.departureCity,
    this.arrivalCity,
    this.departureDate,
    this.expiresAt,
    this.messages = const [],
  });

  factory BidNegotiation.fromJson(Map<String, dynamic> json) => BidNegotiation(
    bidId: json['bidId'] as String,
    announcementId: json['announcementId'] as String,
    status: json['status'] as String,
    round: (json['round'] as num?)?.toInt() ?? 0,
    maxRounds: (json['maxRounds'] as num?)?.toInt() ?? 0,
    myTurn: json['myTurn'] as bool? ?? false,
    canCounter: json['canCounter'] as bool? ?? false,
    currency: json['currency'] as String? ?? 'EUR',
    proposedGrossEur: _asDouble(json['proposedGrossEur']) ?? 0,
    netEur: _asDouble(json['netEur']),
    commissionEur: _asDouble(json['commissionEur']),
    suggestedGrossEur: _asDouble(json['suggestedGrossEur']),
    weightKg: _asDouble(json['weightKg']),
    description: json['description'] as String?,
    contentCategory: json['contentCategory'] as String?,
    gridItems: ((json['gridItems'] as List<dynamic>?) ?? const [])
        .map((e) => BidGridLine.fromJson(e as Map<String, dynamic>))
        .toList(),
    customItems: ((json['customItems'] as List<dynamic>?) ?? const [])
        .map((e) => BidCustomItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    photoUrls: ((json['photoUrls'] as List<dynamic>?) ?? const [])
        .map((e) => e as String)
        .toList(),
    counterpartyName: json['counterpartyName'] as String?,
    departureCity: json['departureCity'] as String?,
    arrivalCity: json['arrivalCity'] as String?,
    departureDate: _asDate(json['departureDate']),
    expiresAt: _asDate(json['expiresAt']),
    messages: ((json['messages'] as List<dynamic>?) ?? const [])
        .map((e) => BidNegotiationMessage.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// C'est à moi de jouer : je peux accepter, contre-proposer ou refuser.
  bool get isMyTurn => myTurn;

  /// Le fil ne se négocie plus (accepté, refusé, annulé, expiré).
  bool get isClosed => status != 'NEGOTIATING';
}

/// Ligne de la liste « Discussions de prix » côté trajet.
class BidNegotiationSummary {
  final String bidId;
  final String announcementId;
  final String status;
  final int round;
  final bool myTurn;
  final bool hasUnread;
  final double proposedGrossEur;
  final String currency;
  final String? counterpartyName;
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? departureDate;
  final DateTime? updatedAt;

  /// Point de vue du demandeur : `SENDER` ou `TRAVELER`.
  final String? role;

  const BidNegotiationSummary({
    required this.bidId,
    required this.announcementId,
    required this.status,
    this.round = 0,
    this.myTurn = false,
    this.hasUnread = false,
    this.proposedGrossEur = 0,
    this.currency = 'EUR',
    this.counterpartyName,
    this.departureCity,
    this.arrivalCity,
    this.departureDate,
    this.updatedAt,
    this.role,
  });

  factory BidNegotiationSummary.fromJson(Map<String, dynamic> json) =>
      BidNegotiationSummary(
        bidId: json['bidId'] as String,
        announcementId: json['announcementId'] as String,
        status: json['status'] as String,
        round: (json['round'] as num?)?.toInt() ?? 0,
        myTurn: json['myTurn'] as bool? ?? false,
        hasUnread: json['hasUnread'] as bool? ?? false,
        proposedGrossEur: _asDouble(json['proposedGrossEur']) ?? 0,
        currency: json['currency'] as String? ?? 'EUR',
        counterpartyName: json['counterpartyName'] as String?,
        departureCity: json['departureCity'] as String?,
        arrivalCity: json['arrivalCity'] as String?,
        departureDate: _asDate(json['departureDate']),
        updatedAt: _asDate(json['updatedAt']),
        role: json['role'] as String?,
      );

  /// Même règle que le fil : seul `NEGOTIATING` reste ouvert.
  bool get isClosed => status != 'NEGOTIATING';
}
