import 'package:dony/features/matching/data/models/commission_shortfall.dart';

enum AcceptanceStatus { accepted, requires3ds, insufficientWallet, failed }

class AcceptanceResponse {
  final AcceptanceStatus status;
  final String? clientSecret;
  final String? paymentIntentId;
  final String? error;
  final double? availableBalance;
  final double? requiredCommission;
  final bool? hasCard;
  final String? currency;
  final CommissionShortfall? breakdown;

  const AcceptanceResponse({
    required this.status,
    this.clientSecret,
    this.paymentIntentId,
    this.error,
    this.availableBalance,
    this.requiredCommission,
    this.hasCard,
    this.currency,
    this.breakdown,
  });

  factory AcceptanceResponse.fromJson(Map<String, dynamic> json) {
    final status = switch (json['status'] as String? ?? '') {
      'ACCEPTED' => AcceptanceStatus.accepted,
      'REQUIRES_3DS' => AcceptanceStatus.requires3ds,
      'INSUFFICIENT_WALLET' => AcceptanceStatus.insufficientWallet,
      _ => AcceptanceStatus.failed,
    };
    return AcceptanceResponse(
      status: status,
      clientSecret: json['clientSecret'] as String?,
      paymentIntentId: json['paymentIntentId'] as String?,
      error: json['error'] as String?,
      availableBalance: (json['availableBalance'] as num?)?.toDouble(),
      requiredCommission: (json['requiredCommission'] as num?)?.toDouble(),
      hasCard: json['hasCard'] as bool?,
      currency: json['currency'] as String?,
      breakdown: json['breakdown'] is Map<String, dynamic>
          ? CommissionShortfall.fromJson(
              json['breakdown'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class ConfirmResponse {
  final bool accepted;
  final String? error;

  const ConfirmResponse({required this.accepted, this.error});

  factory ConfirmResponse.fromJson(Map<String, dynamic> json) =>
      ConfirmResponse(
        accepted: json['accepted'] as bool? ?? false,
        error: json['error'] as String?,
      );
}
