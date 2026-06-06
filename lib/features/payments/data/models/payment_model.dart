import 'package:dony/features/payments/data/models/payment_status.dart';
import 'package:json_annotation/json_annotation.dart';

part 'payment_model.g.dart';

@JsonSerializable()
class PaymentModel {
  final String id;
  // Nullable: negotiation-flow payments (dedicated / linked trips paid via Stripe)
  // are stored against the negotiation thread with a NULL bid_id — the backend
  // returns "bidId": null for those. A non-null type here threw on parse and made
  // the sender's paid shipment fall back to the "Payer mon envoi" button.
  final String? bidId;
  final String? clientSecret;
  final double amount;
  final double commissionAmount;
  final PaymentStatus status;
  @JsonKey(defaultValue: false)
  final bool disputed;

  const PaymentModel({
    required this.id,
    this.bidId,
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
