/// Réponse d'initiation d'une recharge mobile money, `POST /wallet/topup`
/// avec `paymentMethod: 'MOBILE_MONEY'`. L'app poll ensuite le statut
/// (`WalletTopupStatusModel`) avec [topupId], et ouvre [authorizationUrl]
/// quand l'opérateur autorise par redirection (Wave) ; `null` sinon
/// (Orange Money, PIN saisi côté opérateur sans redirection).
class WalletTopupModel {
  const WalletTopupModel({
    required this.topupId,
    required this.currency,
    required this.provider,
    required this.providerLabel,
    required this.msisdnMasked,
    this.authorizationUrl,
  });

  final String topupId;
  final String currency;
  final String provider;
  final String providerLabel;
  final String msisdnMasked;
  final String? authorizationUrl;

  factory WalletTopupModel.fromJson(Map<String, dynamic> json) =>
      WalletTopupModel(
        topupId: json['topupId'] as String,
        currency: json['currency'] as String,
        provider: json['provider'] as String,
        providerLabel: json['providerLabel'] as String,
        msisdnMasked: json['msisdnMasked'] as String,
        authorizationUrl: json['authorizationUrl'] as String?,
      );
}
