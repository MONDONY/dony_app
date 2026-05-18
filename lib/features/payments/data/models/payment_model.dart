import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:json_annotation/json_annotation.dart';

part 'payment_model.g.dart';

@JsonSerializable()
class PaymentModel {
  final String id;
  final String bidId;
  final String? clientSecret;
  final double amount;
  final double commissionAmount;
  final PaymentStatus status;
  @JsonKey(defaultValue: false)
  final bool disputed;

  const PaymentModel({
    required this.id,
    required this.bidId,
    this.clientSecret,
    required this.amount,
    required this.commissionAmount,
    required this.status,
    this.disputed = false,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) =>
      _$PaymentModelFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentModelToJson(this);
}
