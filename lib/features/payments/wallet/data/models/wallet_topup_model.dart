import 'package:dony/features/payments/data/models/mobile_money_countries.dart';

/// Réponse d'initiation d'une recharge mobile money, `POST /wallet/topup`
/// avec `paymentMethod: 'MOBILE_MONEY'`. L'app poll ensuite le statut
/// (`WalletTopupStatusModel`) avec [topupId], et ouvre [authorizationUrl]
/// quand l'opérateur autorise par redirection (Wave) ; `null` sinon
/// (Orange Money, PIN saisi côté opérateur sans redirection).
///
/// [expiresAt] (instant UTC où la demande expire) et [validationHint]
/// (comment l'opérateur fait valider) sont absents d'un back ancien :
/// `null` et [MobileMoneyValidationHint.generic].
class WalletTopupModel {
  const WalletTopupModel({
    required this.topupId,
    required this.currency,
    required this.provider,
    required this.providerLabel,
    required this.msisdnMasked,
    this.authorizationUrl,
    this.expiresAt,
    this.validationHint = MobileMoneyValidationHint.generic,
  });

  final String topupId;
  final String currency;
  final String provider;
  final String providerLabel;
  final String msisdnMasked;
  final String? authorizationUrl;
  final DateTime? expiresAt;
  final MobileMoneyValidationHint validationHint;

  factory WalletTopupModel.fromJson(Map<String, dynamic> json) =>
      WalletTopupModel(
        topupId: json['topupId'] as String,
        currency: json['currency'] as String,
        provider: json['provider'] as String,
        providerLabel: json['providerLabel'] as String,
        msisdnMasked: json['msisdnMasked'] as String,
        authorizationUrl: json['authorizationUrl'] as String?,
        expiresAt: _parseInstant(json['expiresAt']),
        validationHint: MobileMoneyValidationHint.fromWire(
          json['validationHint'] as String?,
        ),
      );
}

/// Instant ISO-8601 du back, en UTC ; `null` si absent ou illisible.
DateTime? _parseInstant(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;
