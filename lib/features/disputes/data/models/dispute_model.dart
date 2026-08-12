/// Litige vu par l'utilisateur courant (lecture seule).
/// Miroir du DTO backend `DisputeResponse` (GET /disputes/me).
class DisputeModel {
  final String id;
  final String? bidId;
  final String type;
  final String status; // OPEN | RESOLVED
  final bool refundFrozen;
  final DateTime createdAt;
  final String myRole; // SENDER | TRAVELER
  final String? otherPartyName;
  final String? departureCity;
  final String? arrivalCity;
  final String? departureCountryCode;
  final String? arrivalCountryCode;
  final DateTime? tripDate;
  final double? weightKg;
  final String? resolutionType;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final int? guaranteeAmountCents;
  final bool isBeneficiary;

  const DisputeModel({
    required this.id,
    required this.bidId,
    required this.type,
    required this.status,
    required this.refundFrozen,
    required this.createdAt,
    required this.myRole,
    required this.otherPartyName,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureCountryCode,
    required this.arrivalCountryCode,
    required this.tripDate,
    required this.weightKg,
    required this.resolutionType,
    required this.resolvedAt,
    required this.resolutionNote,
    required this.guaranteeAmountCents,
    required this.isBeneficiary,
  });

  bool get isOpen => status == 'OPEN';
  bool get isResolved => status == 'RESOLVED';

  factory DisputeModel.fromJson(Map<String, dynamic> json) => DisputeModel(
    id: json['id'] as String,
    bidId: json['bidId'] as String?,
    type: json['type'] as String,
    status: json['status'] as String,
    refundFrozen: json['refundFrozen'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    myRole: json['myRole'] as String,
    otherPartyName: json['otherPartyName'] as String?,
    departureCity: json['departureCity'] as String?,
    arrivalCity: json['arrivalCity'] as String?,
    departureCountryCode: json['departureCountryCode'] as String?,
    arrivalCountryCode: json['arrivalCountryCode'] as String?,
    tripDate: json['tripDate'] != null
        ? DateTime.parse(json['tripDate'] as String)
        : null,
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    resolutionType: json['resolutionType'] as String?,
    resolvedAt: json['resolvedAt'] != null
        ? DateTime.parse(json['resolvedAt'] as String)
        : null,
    resolutionNote: json['resolutionNote'] as String?,
    guaranteeAmountCents: (json['guaranteeAmountCents'] as num?)?.toInt(),
    isBeneficiary: json['isBeneficiary'] as bool? ?? false,
  );
}
