import 'package:dony/features/matching/data/models/commission_funding_alternative.dart';
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

  /// Devise du trajet (colis ou fil), absente d'un ancien back.
  final String? bidCurrency;

  /// Autres portefeuilles capables de couvrir le reste au taux du jour. Vide
  /// avec un ancien back.
  final List<CommissionFundingAlternative> alternatives;

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
    this.bidCurrency,
    this.alternatives = const [],
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
      bidCurrency: (json['bidCurrency'] as String?)?.toUpperCase(),
      alternatives: CommissionFundingAlternative.listFromJson(
        json['alternatives'],
      ),
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
