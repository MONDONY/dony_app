/// Un colis que l'utilisateur va recevoir : l'expéditeur a saisi son numéro
/// comme destinataire, et ce numéro correspond à son compte Yadony.
///
/// Servi par `GET /receptions` et `GET /receptions/{bidId}`
/// (`ReceptionResponse`). Tant que le lien est `PENDING`, le back ne livre
/// que de quoi reconnaître le colis (prénom de l'expéditeur, trajet, dates) :
/// numéro de suivi, voyageur, poids, instructions et code restent `null`. Le
/// code de retrait n'arrive qu'au lien `CONFIRMED`, une fois le colis confié
/// au voyageur.
class Reception {
  const Reception({
    required this.bidId,
    required this.linkStatus,
    required this.bidStatus,
    this.senderFirstName,
    this.departureCity,
    this.arrivalCity,
    this.departureDate,
    this.arrivalDate,
    this.recipientName,
    this.trackingNumber,
    this.travelerFirstName,
    this.arrivalInstructions,
    this.weightKg,
    this.confirmationCode,
    this.updatedAt,
    this.travelerId,
    this.travelerAvatarUrl,
    this.senderId,
    this.senderAvatarUrl,
  });

  static const pending = 'PENDING';
  static const confirmed = 'CONFIRMED';

  final String bidId;

  /// `PENDING` (à confirmer) ou `CONFIRMED`. Jamais `DECLINED` : le back ne
  /// sert plus un colis refusé.
  final String linkStatus;

  /// Statut du bid : `ACCEPTED`, `HANDED_OVER`, `IN_TRANSIT`, `ARRIVED`,
  /// `COMPLETED`.
  final String bidStatus;

  /// Prénom seul, jamais le nom complet ni le téléphone.
  final String? senderFirstName;
  final String? departureCity;
  final String? arrivalCity;
  final DateTime? departureDate;
  final DateTime? arrivalDate;

  /// Nom du destinataire tel que l'expéditeur l'a saisi.
  final String? recipientName;
  final String? trackingNumber;
  final String? travelerFirstName;
  final String? arrivalInstructions;
  final double? weightKg;
  final String? confirmationCode;
  final DateTime? updatedAt;

  /// Voyageur, une fois le colis confirmé : ouvre son profil public (Sentry
  /// FLUTTER-6G/6H). `null` avant confirmation ou sur un back antérieur.
  final String? travelerId;
  final String? travelerAvatarUrl;

  /// Expéditeur : ouvre son profil public depuis la carte « Expéditeur »
  /// (Sentry FLUTTER-7P). `null` sur un back antérieur, la carte est alors
  /// absente et seul le titre nomme l'expéditeur.
  final String? senderId;
  final String? senderAvatarUrl;

  bool get isPending => linkStatus == pending;
  bool get isConfirmed => linkStatus == confirmed;

  /// Statuts d'un colis encore en cours : le destinataire peut écrire au
  /// voyageur. Au-delà (`COMPLETED`), la conversation n'est plus qu'en
  /// lecture et aucune nouvelle entrée n'est proposée.
  static const activeBidStatuses = <String>{
    'ACCEPTED',
    'HANDED_OVER',
    'IN_TRANSIT',
    'ARRIVED',
  };

  /// Le destinataire peut ouvrir la conversation avec le voyageur (lot 3C) :
  /// lien `CONFIRMED` et colis non terminé.
  bool get canMessageTraveler =>
      isConfirmed && activeBidStatuses.contains(bidStatus);

  /// Le destinataire peut montrer le QR du colis au voyageur : lien
  /// `CONFIRMED` (le back refuse le QR sinon, en 403) et colis pas encore
  /// remis. Le QR identifie le colis au scan ; la remise exige toujours le
  /// code de retrait.
  bool get canShowParcelQr =>
      isConfirmed && activeBidStatuses.contains(bidStatus);

  /// Le destinataire peut se retirer du colis (FLUTTER-9F) : lien
  /// `CONFIRMED` et colis encore en cours. Le back prévient l'expéditeur,
  /// invité à désigner quelqu'un d'autre, et le voyageur.
  bool get canWithdraw => isConfirmed && activeBidStatuses.contains(bidStatus);

  factory Reception.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    DateTime? date(String key) {
      final value = json[key];
      return value is String ? DateTime.tryParse(value) : null;
    }

    return Reception(
      bidId: json['bidId'] as String,
      // Un back qui omettrait le statut du lien ne doit pas livrer un code :
      // à défaut, le colis reste « à confirmer ».
      linkStatus: text('linkStatus') ?? pending,
      bidStatus: text('bidStatus') ?? '',
      senderFirstName: text('senderFirstName'),
      departureCity: text('departureCity'),
      arrivalCity: text('arrivalCity'),
      departureDate: date('departureDate'),
      arrivalDate: date('arrivalDate'),
      recipientName: text('recipientName'),
      trackingNumber: text('trackingNumber'),
      travelerFirstName: text('travelerFirstName'),
      arrivalInstructions: text('arrivalInstructions'),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      confirmationCode: text('confirmationCode'),
      updatedAt: date('updatedAt'),
      travelerId: text('travelerId'),
      travelerAvatarUrl: text('travelerAvatarUrl'),
      senderId: text('senderId'),
      senderAvatarUrl: text('senderAvatarUrl'),
    );
  }
}
