import 'package:dony/features/payments/wallet/data/models/wallet_transaction_model.dart';
import 'package:dony/l10n/l10n.dart';

/// Libellé d'une ligne de l'historique du solde, d'après son code serveur
/// (`WalletTransactionType`), jamais affiché brut.
///
/// Le back n'expose ni l'opérateur ni le numéro sur les lignes de
/// transaction (contrairement à `WalletTopupStatusModel`, propre au sondage
/// de la recharge en cours) : seul `isMobileMoneyTopup` (préfixe `pawapay:`
/// du `paymentRef`) distingue le rail d'une recharge. De même, seul le
/// `paymentRef` (`supplement-refund-<id>`) distingue la commission d'un
/// supplément rendue d'un autre remboursement. Un type inconnu de cette
/// version (back plus récent) prend un libellé générique.
String walletTxLabel(AppLocalizations l, WalletTransactionModel tx) =>
    switch (tx.type) {
      'TOP_UP' when tx.isMobileMoneyTopup => // i18n-ignore
      l.walletTxTypeMobileMoneyTopUp,
      'TOP_UP' => l.walletTxTypeTopUp, // i18n-ignore
      'BID_PAYMENT' => l.walletTxTypeBidPayment, // i18n-ignore
      'COMMISSION_DEDUCTED' => l.walletTxTypeCommission, // i18n-ignore
      'SUPPLEMENT_COMMISSION_DEDUCTED' => // i18n-ignore
      l.walletTxTypeSupplementCommission,
      'REFUND' when tx.isSupplementCommissionRefund => // i18n-ignore
      l.walletTxTypeSupplementCommissionRefund,
      'REFUND' || 'SELF_REFUND_OUT' => l.walletTxTypeRefund, // i18n-ignore
      'REFERRAL_REWARD' => l.walletTxTypeReferral, // i18n-ignore
      'TOP_UP_CODE' => l.walletTxTypeTopUpCode, // i18n-ignore
      'ADMIN_CREDIT' => l.walletTxTypeAdminCredit, // i18n-ignore
      'ADMIN_DEBIT' => l.walletTxTypeAdminDebit, // i18n-ignore
      'FORFEITED_ON_DELETION' => l.walletTxTypeForfeited, // i18n-ignore
      'TOPUP_DISPUTED' => l.walletTxTypeTopupDisputed, // i18n-ignore
      'TOPUP_DISPUTE_REVERSED' => // i18n-ignore
      l.walletTxTypeTopupDisputeReversed,
      _ => l.walletTxTypeOther,
    };
