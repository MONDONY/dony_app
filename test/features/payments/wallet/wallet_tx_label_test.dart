import 'package:dony/features/payments/wallet/data/models/wallet_transaction_model.dart';
import 'package:dony/features/payments/wallet/presentation/wallet_tx_label.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';

WalletTransactionModel _tx(String type, {String? paymentRef}) =>
    WalletTransactionModel(
      type: type,
      amount: type == 'REFUND' ? 1.8 : -1.8,
      currency: 'EUR',
      balanceAfter: 10,
      paymentRef: paymentRef,
      createdAt: DateTime(2026, 10, 19),
    );

void main() {
  final fr = lookupAppLocalizations(AppL10n.fr);
  final en = lookupAppLocalizations(AppL10n.en);

  test(
    'commission de supplément prélevée (SUPPLEMENT_COMMISSION_DEDUCTED)',
    () {
      final tx = _tx(
        'SUPPLEMENT_COMMISSION_DEDUCTED',
        paymentRef: 'supplement-6f1c',
      );
      expect(walletTxLabel(fr, tx), 'Frais de service de supplément');
      expect(walletTxLabel(en, tx), 'Supplement commission');
    },
  );

  test('commission de supplément rendue : REFUND supplement-refund-', () {
    final tx = _tx('REFUND', paymentRef: 'supplement-refund-6f1c');
    expect(tx.isSupplementCommissionRefund, isTrue);
    expect(walletTxLabel(fr, tx), 'Frais de service de supplément rendus');
    expect(walletTxLabel(en, tx), 'Supplement commission refunded');
  });

  test('autre remboursement : libellé habituel', () {
    final tx = _tx('REFUND', paymentRef: 'refund-pi_1');
    expect(tx.isSupplementCommissionRefund, isFalse);
    expect(walletTxLabel(fr, tx), 'Remboursement');
    expect(walletTxLabel(fr, _tx('REFUND')), 'Remboursement');
  });

  test('types connus inchangés', () {
    expect(walletTxLabel(fr, _tx('COMMISSION_DEDUCTED')), 'Frais de service');
    expect(walletTxLabel(fr, _tx('TOP_UP')), 'Recharge');
    expect(
      walletTxLabel(fr, _tx('TOP_UP', paymentRef: 'pawapay:1')),
      'Recharge mobile money',
    );
    expect(walletTxLabel(fr, _tx('SELF_REFUND_OUT')), 'Remboursement');
    expect(walletTxLabel(fr, _tx('BID_PAYMENT')), 'Paiement colis');
    expect(walletTxLabel(fr, _tx('REFERRAL_REWARD')), 'Parrainage');
    expect(walletTxLabel(fr, _tx('TOP_UP_CODE')), 'Code de recharge');
    expect(walletTxLabel(fr, _tx('ADMIN_CREDIT')), 'Crédit Yadony');
    expect(walletTxLabel(fr, _tx('ADMIN_DEBIT')), 'Ajustement Yadony');
    expect(
      walletTxLabel(fr, _tx('FORFEITED_ON_DELETION')),
      'Crédit perdu (compte supprimé)',
    );
  });

  test(
    'type inconnu (back plus récent) : libellé générique, jamais le code',
    () {
      final tx = _tx('SOMETHING_NEW');
      expect(walletTxLabel(fr, tx), 'Mouvement du solde');
      expect(walletTxLabel(en, tx), 'Balance movement');
    },
  );
}
