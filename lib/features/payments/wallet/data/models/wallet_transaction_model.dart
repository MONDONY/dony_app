import 'package:dony/core/utils/server_date_time.dart';

class WalletTransactionModel {
  final String type;
  final double amount;

  /// Code ISO de la devise de cette ligne (`XOF`, `EUR`...). La liste du back
  /// mêle tous les portefeuilles de l'utilisateur : une recharge mobile money
  /// en XOF côtoie un remboursement Stripe en EUR. `null` avec un ancien
  /// contrat back, l'écran retombe alors sur la devise du portefeuille actif.
  final String? currency;
  final double balanceAfter;
  final String? paymentRef;
  final DateTime createdAt;

  /// null, 'PROCESSING' ou 'REFUNDED' — statut du remboursement en cours sur
  /// cette recharge, s'il y en a un (cf. WalletSelfRefundService côté back).
  final String? refundStatus;

  /// Colis (bid) sur lequel porte la ligne : commission prélevée,
  /// remboursement, paiement d'un colis. `null` pour une ligne sans colis
  /// (recharge, parrainage...) et avec un back antérieur au champ, qui ne
  /// l'envoie pas : la ligne reste alors non cliquable.
  final String? bidId;

  /// Origine d'une ligne convertie : devise et montant de la part de
  /// commission qu'elle règle (« pour 450 F CFA »). Absents pour une ligne non
  /// convertie et avec un back antérieur au champ. Jamais le taux, qui paraîtrait
  /// faux (il est recalculé sur des montants arrondis).
  final String? sourceCurrency;
  final double? sourceAmount;

  const WalletTransactionModel({
    required this.type,
    required this.amount,
    this.currency,
    required this.balanceAfter,
    this.paymentRef,
    required this.createdAt,
    this.refundStatus,
    this.bidId,
    this.sourceCurrency,
    this.sourceAmount,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) =>
      WalletTransactionModel(
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: (json['currency'] as String?)?.toUpperCase(),
        balanceAfter: (json['balanceAfter'] as num).toDouble(),
        paymentRef: json['paymentRef'] as String?,
        createdAt: parseServerDateTime(json['createdAt'] as String).toLocal(),
        refundStatus: json['refundStatus'] as String?,
        bidId: _bidIdOf(json['bidId']),
        sourceCurrency: _currencyOf(json['sourceCurrency']),
        sourceAmount: (json['sourceAmount'] as num?)?.toDouble(),
      );

  /// Tolérant : absent, `null`, vide ou d'un autre type → pas de colis.
  static String? _bidIdOf(Object? raw) =>
      raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

  /// Tolérant : absent, `null`, vide ou d'un autre type → pas de devise.
  static String? _currencyOf(Object? raw) =>
      raw is String && raw.trim().isNotEmpty ? raw.trim().toUpperCase() : null;

  /// La ligne vient d'une conversion : elle porte la devise et le montant
  /// d'origine à afficher.
  bool get hasSource => sourceCurrency != null && sourceAmount != null;

  bool get isCredit => amount > 0;
  bool get isRefundProcessing =>
      refundStatus == 'PROCESSING'; // i18n-ignore : code serveur comparé

  /// `paymentRef` d'un dépôt pawaPay : préfixe `pawapay:` suivi de l'UUID de
  /// l'opération `pawapay_operations` (cf. `WalletRefundRail` côté back,
  /// `WalletTopupOutcomeListener`). Un rail Stripe (`pi_...`) ou un
  /// `paymentRef` nul rendent faux.
  bool get isMobileMoneyTopup => paymentRef?.startsWith('pawapay:') ?? false;

  /// Commission d'un supplément de prix rendue au voyageur (colis payé en
  /// espèces) : ligne `REFUND` au `paymentRef` `supplement-refund-<id>`.
  bool get isSupplementCommissionRefund =>
      paymentRef?.startsWith('supplement-refund-') ?? false;
}
