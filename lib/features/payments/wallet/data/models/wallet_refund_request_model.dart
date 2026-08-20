class WalletRefundRequestModel {
  final String id;
  final String currency;
  final double amount;
  final String channel;
  final String status;
  final DateTime requestedAt;
  final DateTime? resolvedAt;

  const WalletRefundRequestModel({
    required this.id,
    required this.currency,
    required this.amount,
    required this.channel,
    required this.status,
    required this.requestedAt,
    this.resolvedAt,
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
      );

  bool get isTerminal =>
      status == 'RESOLVED' || status == 'REFUNDED' || status == 'FAILED';

  bool get isSuccess => status == 'RESOLVED' || status == 'REFUNDED';
}
