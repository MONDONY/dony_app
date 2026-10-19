import 'package:dony/features/payments/data/models/mobile_money_countries.dart';

/// Statut d'une recharge mobile money, relu en boucle par l'app pendant
/// l'attente du PIN (`GET /wallet/topup/{topupId}/status`).
///
/// Les statuts pawaPay sont ramenés à trois valeurs côté back : `PENDING`
/// (on attend), `CONFIRMED` (portefeuille crédité, [walletBalance]
/// renseigné) et `FAILED` (l'utilisateur peut recommencer, [failureReason]
/// renseigné).
///
/// [expiresAt], [validationHint] et [failureCode] sont absents d'un back
/// ancien : `null`, [MobileMoneyValidationHint.generic] et `null`.
class WalletTopupStatusModel {
  const WalletTopupStatusModel({
    required this.topupId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.provider,
    required this.providerLabel,
    required this.msisdnMasked,
    this.authorizationUrl,
    this.failureReason,
    this.walletBalance,
    this.expiresAt,
    this.validationHint = MobileMoneyValidationHint.generic,
    this.failureCode,
  });

  final String topupId;

  /// PENDING | CONFIRMED | FAILED
  final String status;
  final double amount;
  final String currency;
  final String provider;
  final String providerLabel;
  final String msisdnMasked;
  final String? authorizationUrl;
  final String? failureReason;

  /// Solde après crédit, uniquement sur `CONFIRMED` ; `null` sinon, pour ne
  /// pas laisser croire qu'un solde inchangé est un solde crédité.
  final double? walletBalance;

  /// Instant UTC où la demande expire ; `null` si le back ne le dit pas.
  final DateTime? expiresAt;
  final MobileMoneyValidationHint validationHint;

  /// Code Yadony du motif d'échec (`insufficient-balance`, `not-approved`,
  /// `payer-limit-reached`, `invalid-number`, `provider-unavailable`,
  /// `expired`, `other`) ; `null` hors échec ou sur un back ancien.
  final String? failureCode;

  factory WalletTopupStatusModel.fromJson(Map<String, dynamic> json) =>
      WalletTopupStatusModel(
        topupId: json['topupId'] as String,
        status: json['status'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String,
        provider: json['provider'] as String,
        providerLabel: json['providerLabel'] as String,
        msisdnMasked: json['msisdnMasked'] as String,
        authorizationUrl: json['authorizationUrl'] as String?,
        failureReason: json['failureReason'] as String?,
        walletBalance: (json['walletBalance'] as num?)?.toDouble(),
        expiresAt: _parseInstant(json['expiresAt']),
        validationHint: MobileMoneyValidationHint.fromWire(
          json['validationHint'] as String?,
        ),
        failureCode: json['failureCode'] as String?,
      );
}

/// Instant ISO-8601 du back, en UTC ; `null` si absent ou illisible.
DateTime? _parseInstant(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;
