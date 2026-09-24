import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_currency_balance_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Choix de la devise à rembourser quand plusieurs portefeuilles sont
/// éligibles. Une demande de remboursement = une devise (contrainte back) :
/// la sheet rend le solde choisi, l'appelant ouvre ensuite
/// `WalletRefundConfirmSheet` pour cette devise.
class WalletRefundCurrencySheet extends StatelessWidget {
  const WalletRefundCurrencySheet._({
    required this.balances,
    required this.selected,
  });

  final List<WalletCurrencyBalanceModel> balances;
  final ValueNotifier<WalletCurrencyBalanceModel?> selected;

  static Future<WalletCurrencyBalanceModel?> show(
    BuildContext context, {
    required List<WalletCurrencyBalanceModel> balances,
  }) {
    // Seul un geste utilisateur écrit dans ce notifier (onTap) : il peut être
    // disposé dans whenComplete (règle du CLAUDE.md sur les bottom sheets).
    final selected = ValueNotifier<WalletCurrencyBalanceModel?>(null);
    return DonyBottomSheet.show<WalletCurrencyBalanceModel?>(
      context,
      title: 'Quelle devise rembourser ?',
      stickyBottom: ValueListenableBuilder<WalletCurrencyBalanceModel?>(
        valueListenable: selected,
        builder: (context, value, _) => DonyButton(
          label: 'Continuer',
          onPressed: value == null
              ? null
              : () => Navigator.of(context).pop(value),
        ),
      ),
      child: WalletRefundCurrencySheet._(
        balances: balances,
        selected: selected,
      ),
    ).whenComplete(selected.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<WalletCurrencyBalanceModel?>(
      valueListenable: selected,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Une demande par devise. Tu pourras en faire une autre ensuite.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: DonySpacing.lg),
          DonyExpandableChoice<String?>(
            value: value?.currency,
            onChanged: (code) =>
                selected.value = balances.firstWhere((b) => b.currency == code),
            choices: [for (final b in balances) _choice(b)],
          ),
        ],
      ),
    );
  }

  static DonyChoice<String?> _choice(WalletCurrencyBalanceModel b) {
    final currency = SupportedCurrency.fromCodeOrDefault(b.currency);
    final gross = b.refundableAmount ?? 0;
    final fee = b.refundFeeAmount;
    final net = b.refundNetAmount ?? gross;
    // `fee == null` : le back ne renseigne pas encore ce champ (ancien
    // contrat) — on ne dit rien plutôt que d'inventer une valeur. `fee == 0`
    // seul cas où « Offerts » s'affiche.
    final feeText = fee == null
        ? null
        : (fee == 0
              ? 'Frais de remboursement : Offerts'
              : 'Frais de remboursement : ${CurrencyFormatter.format(fee, currency)}');
    return DonyChoice<String?>(
      key: Key('wallet-refund-currency-${b.currency.toUpperCase()}'),
      value: b.currency,
      title: '${CurrencyFormatter.format(gross, currency)} remboursables',
      subtitle: 'tu reçois ${CurrencyFormatter.format(net, currency)}',
      iconAsset: b.active ? 'wallet' : 'globe',
      expanded: (context) => Text(
        feeText == null
            ? '${currency.name(context.l10n)}.'
            : '$feeText. ${currency.name(context.l10n)}.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
