class WalletRefundRequestModel {
  final String id;
  final String currency;
  final double amount;
  final String channel;
  final String status;
  final DateTime requestedAt;
  final DateTime? resolvedAt;

  /// Somme des frais retenus sur les items de la demande (mobile money :
  /// pawaPay). `null` tant que le back n'expose pas encore le champ.
  final double? feeAmount;

  /// Net réellement reparti vers l'utilisateur. `null` sur l'ancien contrat.
  final double? netAmount;

  /// Rail du remboursement : `STRIPE`, `PAWAPAY` ou `MANUAL`. `null` sur
  /// l'ancien contrat.
  final String? rail;

  /// Numéro masqué du dépôt mobile money d'origine (`PAWAPAY` uniquement),
  /// jamais en clair. `null` hors pawaPay ou sur l'ancien contrat.
  final String? destinationMasked;

  const WalletRefundRequestModel({
    required this.id,
    required this.currency,
    required this.amount,
    required this.channel,
    required this.status,
    required this.requestedAt,
    this.resolvedAt,
    this.feeAmount,
    this.netAmount,
    this.rail,
    this.destinationMasked,
  });

  factory WalletRefundRequestModel.fromJson(Map<String, dynamic> json) =>
      WalletRefundRequestModel(
        id: json['id'] as String,
        currency: json['currency'] as String,
        amount: (json['amount'] as num).toDouble(),
        channel: json['channel'] as String,
        status: json['status'] as String,
        requestedAt: DateTime.parse(json['requestedAt'] as String),
        resolvedAt: json['resolvedAt'] != null
            ? DateTime.parse(json['resolvedAt'] as String)
            : null,
        feeAmount: (json['feeAmount'] as num?)?.toDouble(),
        netAmount: (json['netAmount'] as num?)?.toDouble(),
        rail: json['rail'] as String?,
        destinationMasked: json['destinationMasked'] as String?,
      );

  bool get isTerminal =>
      status == 'RESOLVED' || status == 'REFUNDED' || status == 'FAILED';

  bool get isSuccess => status == 'RESOLVED' || status == 'REFUNDED';
}
