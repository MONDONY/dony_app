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

  const WalletTransactionModel({
    required this.type,
    required this.amount,
    this.currency,
    required this.balanceAfter,
    this.paymentRef,
    required this.createdAt,
    this.refundStatus,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) =>
      WalletTransactionModel(
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: (json['currency'] as String?)?.toUpperCase(),
        balanceAfter: (json['balanceAfter'] as num).toDouble(),
        paymentRef: json['paymentRef'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        refundStatus: json['refundStatus'] as String?,
      );

  bool get isCredit => amount > 0;
  bool get isRefundProcessing => refundStatus == 'PROCESSING';

  /// `paymentRef` d'un dépôt pawaPay : préfixe `pawapay:` suivi de l'UUID de
  /// l'opération `pawapay_operations` (cf. `WalletRefundRail` côté back,
  /// `WalletTopupOutcomeListener`). Un rail Stripe (`pi_...`) ou un
  /// `paymentRef` nul rendent faux.
  bool get isMobileMoneyTopup => paymentRef?.startsWith('pawapay:') ?? false;
}
