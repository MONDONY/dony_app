import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/currency_labels.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/wallet/data/models/wallet_currency_balance_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Total estimé exprimé dans la devise [targetCurrency], déduit de ce que le
/// back sait déjà : le total dans la devise courante ([estimatedTotal]) et
/// l'équivalent du solde cible dans cette même devise
/// ([WalletCurrencyBalanceModel.estimatedInActive]). Le taux cible → courante
/// s'en déduit ; aucun taux n'est jamais embarqué dans l'app.
///
/// `null` quand l'un des éléments manque : pas de total, solde cible nul ou
/// sans équivalent (taux indisponible). L'appelant affiche alors
/// l'avertissement sans montant.
double? walletTotalInCurrency({
  required String targetCurrency,
  required double? estimatedTotal,
  required List<WalletCurrencyBalanceModel> balances,
}) {
  if (estimatedTotal == null) return null;
  final code = targetCurrency.toUpperCase();
  for (final b in balances) {
    if (b.currency.toUpperCase() != code) continue;
    final equivalent = b.estimatedInActive;
    if (equivalent == null || equivalent <= 0 || b.balance <= 0) return null;
    return estimatedTotal * b.balance / equivalent;
  }
  return null;
}

/// « Mes soldes » : l'argent de chaque devise, en grand et dans son format, la
/// devise du total (la devise active du portefeuille) et un lien discret pour
/// en changer. Rien n'est converti, la feuille rend seulement le code devise
/// choisi (`null` si fermée sans choix).
///
/// Un choix en attente fait apparaître un avertissement (le total change, pas
/// l'argent) et remplace le bouton « Fermer » du pied par le bouton plein
/// « Calculer le total en … », dans `stickyBottom` (règle des feuilles du
/// projet). La section « Ajouter un portefeuille » reste le seul moyen de
/// créer un portefeuille dans une autre devise.
class WalletBalancesSheet extends StatelessWidget {
  const WalletBalancesSheet._({
    required this.held,
    required this.addable,
    required this.selected,
    required this.active,
    required this.balances,
    required this.estimatedTotal,
  });

  /// Portefeuilles affichés : devise du total en tête, puis par valeur. Les
  /// soldes nuls ne sont gardés que pour la devise du total.
  final List<WalletCurrencyBalanceModel> held;

  /// Devises du catalogue sans portefeuille affiché.
  final List<SupportedCurrency> addable;
  final ValueNotifier<String?> selected;
  final String active;

  /// Tous les soldes reçus, pour déduire le total dans une autre devise.
  final List<WalletCurrencyBalanceModel> balances;
  final double? estimatedTotal;

  static Future<String?> show(
    BuildContext context, {
    required String activeCurrency,
    required List<WalletCurrencyBalanceModel> balances,
    double? estimatedTotal,
  }) {
    final active = activeCurrency.toUpperCase();
    final held = [
      for (final b in balances)
        if (b.currency.toUpperCase() == active || b.balance != 0) b,
    ];
    // Ancien contrat back (aucune ligne par devise) : la devise du total reste
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
      final byValue = (b.estimatedInActive ?? b.balance).compareTo(
        a.estimatedInActive ?? a.balance,
      );
      return byValue != 0 ? byValue : a.currency.compareTo(b.currency);
    });
    final heldCodes = held.map((b) => b.currency.toUpperCase()).toSet();
    final addable = SupportedCurrency.values
        .where((c) => !heldCodes.contains(c.code))
        .toList();

    // Seul un geste utilisateur écrit dans ce notifier (tap d'une carte,
    // onChanged d'un choix) : il peut être disposé dans whenComplete (règle du
    // CLAUDE.md sur les sheets).
    final selected = ValueNotifier<String?>(active);
    return DonyBottomSheet.show<String?>(
      context,
      title: context.l10n.walletBalancesSheetTitle,
      heightFraction: 0.85,
      stickyBottom: ValueListenableBuilder<String?>(
        valueListenable: selected,
        builder: (context, value, _) {
          final l = context.l10n;
          final pending = value != null && value != active;
          if (!pending) {
            return DonyButton(
              key: const Key('wallet-balances-close'),
              label: l.commonClose,
              variant: DonyButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            );
          }
          return DonyButton(
            key: const Key('wallet-balances-confirm'),
            label: l.walletBalancesConfirm(
              SupportedCurrency.fromCodeOrDefault(value).name(l),
            ),
            onPressed: () => Navigator.of(context).pop(value),
          );
        },
      ),
      child: WalletBalancesSheet._(
        held: held,
        addable: addable,
        selected: selected,
        active: active,
        balances: balances,
        estimatedTotal: estimatedTotal,
      ),
    ).whenComplete(selected.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final activeCurrency = SupportedCurrency.fromCodeOrDefault(active);

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
      builder: (context, value, _) {
        final pending = value != null && value != active;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.walletBalancesSheetHint,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            section(l.walletActiveCurrencyHeldSection),
            for (final b in held) ...[
              _BalanceCard(
                balance: b,
                isActive: b.currency.toUpperCase() == active,
                isSelected: b.currency.toUpperCase() == value,
                activeCurrency: activeCurrency,
                onSelect: () => selected.value = b.currency.toUpperCase(),
              ),
              const SizedBox(height: DonySpacing.sm),
            ],
            if (pending) _pendingWarning(context, value),
            if (estimatedTotal != null && held.length > 1) ...[
              const SizedBox(height: DonySpacing.sm),
              _TotalLine(total: estimatedTotal!, currency: activeCurrency),
            ],
            if (addable.isNotEmpty) ...[
              section(l.walletActiveCurrencyAddSection),
              DonyExpandableChoice<String?>(
                value: value,
                onChanged: (code) => selected.value = code,
                choices: [for (final c in addable) _addChoice(l, c)],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _pendingWarning(BuildContext context, String target) {
    final l = context.l10n;
    final targetCurrency = SupportedCurrency.fromCodeOrDefault(target);
    final newTotal = walletTotalInCurrency(
      targetCurrency: target,
      estimatedTotal: estimatedTotal,
      balances: balances,
    );
    return Padding(
      padding: const EdgeInsets.only(top: DonySpacing.xs),
      child: DonyStatusBanner(
        key: const Key('wallet-balances-change-warning'),
        type: DonyStatusBannerType.warning,
        iconAsset: 'circle-alert',
        message: newTotal == null
            ? l.walletBalancesChangeWarningNoAmount(targetCurrency.name(l))
            : l.walletBalancesChangeWarning(
                targetCurrency.name(l),
                CurrencyFormatter.format(newTotal, targetCurrency),
              ),
      ),
    );
  }

  static DonyChoice<String?> _addChoice(
    AppLocalizations l,
    SupportedCurrency currency,
  ) {
    return DonyChoice<String?>(
      key: Key('wallet-balances-add-${currency.code}'),
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

/// Une devise détenue : son solde en grand, dans son format, l'équivalent dans
/// la devise du total au taux du jour, et un lien discret pour la choisir.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.isActive,
    required this.isSelected,
    required this.activeCurrency,
    required this.onSelect,
  });

  final WalletCurrencyBalanceModel balance;
  final bool isActive;
  final bool isSelected;
  final SupportedCurrency activeCurrency;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final currency = SupportedCurrency.fromCodeOrDefault(balance.currency);
    final equivalent = balance.estimatedInActive;

    final Widget? secondLine;
    if (isActive) {
      secondLine = null;
    } else if (equivalent == null) {
      secondLine = Text(
        l.walletRateUnavailable,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      );
    } else {
      secondLine = Text(
        l.walletBalancesEquivalent(
          CurrencyFormatter.format(equivalent, activeCurrency),
        ),
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      );
    }

    return Semantics(
      button: !isActive,
      selected: isSelected,
      label:
          '${currency.name(l)}, '
          '${CurrencyFormatter.format(balance.balance, currency)}',
      child: DecoratedBox(
        key: Key('wallet-balance-card-${currency.code}'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DonyRadius.card + 2),
          border: Border.all(
            color: isSelected ? cs.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: DonyCard(
          onTap: isActive ? null : onSelect,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                    ),
                    child: Text(
                      currency.symbol,
                      style: tt.titleMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currency.name(l),
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          currency.code,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(DonyRadius.sm),
                      ),
                      child: Text(
                        l.walletBalancesTotalBadge,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: DonySpacing.sm),
              Text(
                CurrencyFormatter.format(balance.balance, currency),
                key: Key('wallet-balance-amount-${currency.code}'),
                style: tt.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              ?secondLine,
              if (!isActive && !isSelected) ...[
                const SizedBox(height: DonySpacing.xs),
                Text(
                  l.walletBalancesUseForTotal,
                  style: tt.labelLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({required this.total, required this.currency});

  final double total;
  final SupportedCurrency currency;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.l10n.walletEstimatedTotalLabel,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        Text(
          CurrencyFormatter.format(total, currency),
          key: const Key('wallet-balances-total'),
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
