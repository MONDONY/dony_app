import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_currency_balance_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Choix du portefeuille actif (FLUTTER-8F) : les portefeuilles détenus avec
/// leur solde, puis les devises qu'on peut ajouter. Rien n'est converti, la
/// sheet rend seulement le code devise choisi (`null` si fermée sans choix).
class WalletActiveCurrencySheet extends StatelessWidget {
  const WalletActiveCurrencySheet._({
    required this.held,
    required this.addable,
    required this.selected,
  });

  /// Portefeuilles existants, devise active en tête puis par solde.
  final List<WalletCurrencyBalanceModel> held;

  /// Devises du catalogue sans portefeuille.
  final List<SupportedCurrency> addable;
  final ValueNotifier<String?> selected;

  static Future<String?> show(
    BuildContext context, {
    required String activeCurrency,
    required List<WalletCurrencyBalanceModel> balances,
  }) {
    final active = activeCurrency.toUpperCase();
    final held = [...balances];
    // Ancien contrat back (aucune ligne par devise) : la devise active reste
    // listée comme portefeuille détenu.
    if (!held.any((b) => b.currency.toUpperCase() == active)) {
      held.add(
        WalletCurrencyBalanceModel(currency: active, balance: 0, active: true),
      );
    }
    held.sort((a, b) {
      final aActive = a.currency.toUpperCase() == active;
      final bActive = b.currency.toUpperCase() == active;
      if (aActive != bActive) return aActive ? -1 : 1;
      final byBalance = (b.estimatedInActive ?? b.balance).compareTo(
        a.estimatedInActive ?? a.balance,
      );
      return byBalance != 0 ? byBalance : a.currency.compareTo(b.currency);
    });
    final heldCodes = held.map((b) => b.currency.toUpperCase()).toSet();
    final addable = SupportedCurrency.values
        .where((c) => !heldCodes.contains(c.code))
        .toList();

    // Seul un geste utilisateur écrit dans ce notifier (onChanged) : il peut
    // être disposé dans whenComplete (règle du CLAUDE.md sur les sheets).
    final selected = ValueNotifier<String?>(active);
    return DonyBottomSheet.show<String?>(
      context,
      title: context.l10n.walletActiveCurrencySheetTitle,
      heightFraction: 0.85,
      stickyBottom: ValueListenableBuilder<String?>(
        valueListenable: selected,
        builder: (context, value, _) => DonyButton(
          key: const Key('wallet-active-currency-confirm'),
          label: context.l10n.walletActiveCurrencyConfirm,
          onPressed: value == null || value == active
              ? null
              : () => Navigator.of(context).pop(value),
        ),
      ),
      child: WalletActiveCurrencySheet._(
        held: held,
        addable: addable,
        selected: selected,
      ),
    ).whenComplete(selected.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Widget section(String label) => Padding(
      padding: const EdgeInsets.only(
        top: DonySpacing.lg,
        bottom: DonySpacing.sm,
      ),
      child: Text(
        label,
        style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );

    return ValueListenableBuilder<String?>(
      valueListenable: selected,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.walletActiveCurrencySheetHint,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          section(l.walletActiveCurrencyHeldSection),
          DonyExpandableChoice<String?>(
            value: value,
            onChanged: (code) => selected.value = code,
            choices: [for (final b in held) _heldChoice(l, b)],
          ),
          if (addable.isNotEmpty) ...[
            section(l.walletActiveCurrencyAddSection),
            DonyExpandableChoice<String?>(
              value: value,
              onChanged: (code) => selected.value = code,
              choices: [for (final c in addable) _addChoice(l, c)],
            ),
          ],
        ],
      ),
    );
  }

  static DonyChoice<String?> _heldChoice(
    AppLocalizations l,
    WalletCurrencyBalanceModel b,
  ) {
    final currency = SupportedCurrency.fromCodeOrDefault(b.currency);
    return DonyChoice<String?>(
      key: Key('wallet-active-currency-${currency.code}'),
      value: currency.code,
      title: CurrencyFormatter.format(b.balance, currency),
      subtitle: b.active
          ? '${currency.name(l)} · ${l.walletActiveCurrencyBadge}'
          : currency.name(l),
      iconAsset: 'wallet',
      expanded: (context) => Text(
        context.l10n.walletActiveCurrencyHeldDetail(
          currency.name(context.l10n),
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  static DonyChoice<String?> _addChoice(
    AppLocalizations l,
    SupportedCurrency currency,
  ) {
    return DonyChoice<String?>(
      key: Key('wallet-active-currency-add-${currency.code}'),
      value: currency.code,
      title: l.walletActiveCurrencyAddTitle(currency.name(l)),
      subtitle: '${currency.code} (${currency.symbol})',
      iconAsset: 'plus',
      expanded: (context) => Text(
        context.l10n.walletActiveCurrencyAddDetail,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
