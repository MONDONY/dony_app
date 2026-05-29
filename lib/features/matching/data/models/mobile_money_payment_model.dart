import 'package:equatable/equatable.dart';

class MobileMoneyPaymentModel extends Equatable {
  const MobileMoneyPaymentModel({
    required this.id,
    required this.status,
    required this.amount,
    required this.currency,
    this.paymentLink,
    this.expiresAt,
    this.failureReason,
  });

  final String id;
  final String status;
  final double amount;
  final String currency;
  final String? paymentLink;
  final DateTime? expiresAt;
  final String? failureReason;

  factory MobileMoneyPaymentModel.fromJson(Map<String, dynamic> json) =>
      MobileMoneyPaymentModel(
        id: json['id'] as String,
        status: json['status'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'XOF',
        paymentLink: json['paymentLink'] as String?,
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
        failureReason: json['failureReason'] as String?,
      );

  @override
  List<Object?> get props => [
        id,
        status,
        amount,
        currency,
        paymentLink,
        expiresAt,
        failureReason,
      ];
}
