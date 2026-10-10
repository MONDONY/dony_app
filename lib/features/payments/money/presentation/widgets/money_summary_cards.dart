import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/money_conditions.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Soldes de la carte « Disponible » (FLUTTER-J4) : [main] en grand, [others]
/// en petit dessous.
typedef DisplayedBalances = ({MoneyAmount? main, List<MoneyAmount> others});

/// Met en grand le solde de [activeCurrency] s'il existe, sinon le premier ;
/// les autres soldes suivent dans leur ordre, sans ceux à zéro.
DisplayedBalances orderBalances(
  List<MoneyAmount> amounts,
  String? activeCurrency,
) {
  if (amounts.isEmpty) return (main: null, others: const []);
  final active = activeCurrency?.toUpperCase();
  final index = active == null
      ? -1
      : amounts.indexWhere((a) => a.currency.toUpperCase() == active);
  final mainIndex = index < 0 ? 0 : index;
  return (
    main: amounts[mainIndex],
    others: [
      for (var i = 0; i < amounts.length; i++)
        if (i != mainIndex && amounts[i].amount != 0) amounts[i],
    ],
  );
}

/// Deux cartes en tête de « Mon argent » : « Disponible » (solde de la devise
/// active en grand, autres soldes non nuls dessous, FLUTTER-J4) et « Bloqué jusqu'à livraison » (séquestre et
/// nombre de colis). La seconde disparaît quand le back ne fournit pas encore
/// le suivi du séquestre.
class MoneySummaryCards extends StatelessWidget {
  const MoneySummaryCards({
    super.key,
    required this.overview,
    required this.showBlocked,
  });

  final MoneyOverviewModel overview;
  final bool showBlocked;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    // Voyageur d'abord : c'est son argent qui arrive. Un pur expéditeur voit
    // ce qu'il a payé et qui reste bloqué.
    final asTraveler = overview.travelerItems.isNotEmpty;
    final blocked = asTraveler
        ? overview.travelerUpcoming
        : overview.senderBlocked;
    final blockedCount = asTraveler
        ? overview.travelerUpcomingCount
        : overview.senderBlockedCount;

    final available = _SummaryCard(
      key: const Key('money-available-card'),
      label: l.moneyAvailableLabel,
      amounts: overview.wallet,
      activeCurrency: overview.activeCurrency,
      background: cs.surface,
      border: cs.outline,
      labelColor: cs.onSurfaceVariant,
      amountColor: cs.onSurface,
    );
    if (!showBlocked) return available;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: available),
          const SizedBox(width: DonySpacing.md - 2),
          Expanded(
            child: _SummaryCard(
              key: const Key('money-blocked-card'),
              label: l.moneyBlockedLabel,
              amounts: blocked,
              footer: l.moneyBlockedCount(blockedCount),
              background: cs.secondaryContainer,
              border: cs.secondary.withValues(alpha: 0.25),
              labelColor: cs.onSecondaryContainer,
              amountColor: cs.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    super.key,
    required this.label,
    required this.amounts,
    required this.background,
    required this.border,
    required this.labelColor,
    required this.amountColor,
    this.footer,
    this.activeCurrency,
  });

  final String label;
  final List<MoneyAmount> amounts;

  /// Devise mise en grand, `null` : le premier montant.
  final String? activeCurrency;
  final String? footer;
  final Color background;
  final Color border;
  final Color labelColor;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final balances = orderBalances(amounts, activeCurrency);
    final first = balances.main;
    final main = first == null
        ? formatMoney(0, activeCurrency)
        : formatMoney(first.amount, first.currency);
    final others = balances.others.map(
      (a) => formatMoney(a.amount, a.currency),
    );
    final secondLine = [
      if (others.isNotEmpty) '+ ${others.join(' · ')}',
      ?footer,
    ];
    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(DonyRadius.card + 2),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DonySpacing.xs + 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              main,
              style: tt.headlineLarge?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w800,
                fontFeatures: _tabular,
              ),
            ),
          ),
          for (final line in secondLine) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              line,
              style: tt.bodySmall?.copyWith(
                color: labelColor,
                fontFeatures: _tabular,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
