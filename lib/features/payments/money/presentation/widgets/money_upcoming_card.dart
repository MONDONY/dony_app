import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/money/bloc/money_schedule.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/money_labels.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_amount_lines.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Largeur minimale d'une tuile, à 100 % de texte : en dessous, les quatre
/// tuiles passent sur deux lignes de deux.
const double _kTileMinWidth = 70;

/// Carte de tête de « Mon argent » (FLUTTER-HV, écran F) : total à venir des
/// colis et, pour un voyageur, quatre tuiles d'échéance (cette semaine,
/// semaine prochaine, plus tard, litige). Jamais le solde du portefeuille
/// Yadony.
class MoneyUpcomingCard extends StatelessWidget {
  const MoneyUpcomingCard({
    super.key,
    required this.label,
    required this.amounts,
    required this.zeroCurrency,
    this.buckets,
  });

  /// Carte voyageur : à venir et tuiles d'échéance.
  factory MoneyUpcomingCard.traveler({
    Key? key,
    required MoneySchedule schedule,
    required String label,
    required String zeroCurrency,
  }) => MoneyUpcomingCard(
    key: key,
    label: label,
    amounts: schedule.upcoming,
    zeroCurrency: zeroCurrency,
    buckets: schedule.buckets,
  );

  final String label;
  final List<MoneyAmount> amounts;

  /// Devise du « 0 » affiché quand rien n'est attendu.
  final String zeroCurrency;

  /// `null` : carte expéditeur, sans tuiles.
  final Map<MoneyBucket, List<MoneyAmount>>? buckets;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final main = amounts.isEmpty
        ? formatMoney(0, zeroCurrency)
        : formatMoney(amounts.first.amount, amounts.first.currency);
    final others = amounts.skip(1).toList();
    final buckets = this.buckets;

    return Container(
      key: const Key('money-upcoming-card'),
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(DonyRadius.card + 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: l.moneyAmountsSemantics(
              label,
              amounts.isEmpty ? main : formatAmounts(amounts),
            ),
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      main,
                      key: const Key('money-upcoming-main'),
                      style: tt.headlineLarge?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w800,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                  ),
                  if (others.isNotEmpty)
                    Text(
                      '+ ${formatAmounts(others)}',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onPrimary.withValues(alpha: 0.85),
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (buckets != null) ...[
            const SizedBox(height: DonySpacing.md),
            _BucketTiles(buckets: buckets, zeroCurrency: zeroCurrency),
          ],
        ],
      ),
    );
  }
}

class _BucketTiles extends StatelessWidget {
  const _BucketTiles({required this.buckets, required this.zeroCurrency});

  final Map<MoneyBucket, List<MoneyAmount>> buckets;
  final String zeroCurrency;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tiles = [
      for (final b in MoneyBucket.values)
        _BucketTile(
          key: Key('money-bucket-${b.name}'),
          label: switch (b) {
            MoneyBucket.thisWeek => l.moneyBucketThisWeek,
            MoneyBucket.nextWeek => l.moneyBucketNextWeek,
            MoneyBucket.later => l.moneyBucketLater,
            MoneyBucket.dispute => l.moneyBucketDispute,
          },
          amounts: buckets[b] ?? const [],
          zeroCurrency: zeroCurrency,
          attention: b == MoneyBucket.dispute,
        ),
    ];
    const gap = DonySpacing.sm - 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = MediaQuery.textScalerOf(context).scale(_kTileMinWidth);
        final columns = constraints.maxWidth >= 4 * minWidth + 3 * gap ? 4 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += columns) {
          if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + columns; j++) ...[
                    if (j > i) const SizedBox(width: gap),
                    Expanded(child: tiles[j]),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _BucketTile extends StatelessWidget {
  const _BucketTile({
    super.key,
    required this.label,
    required this.amounts,
    required this.zeroCurrency,
    required this.attention,
  });

  final String label;
  final List<MoneyAmount> amounts;
  final String zeroCurrency;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final shown = amounts.isEmpty ? [MoneyAmount(zeroCurrency, 0)] : amounts;
    // Tuile litige : fond chaud et texte sombre, lisibles dans les deux
    // thèmes ; l'intitulé dit « Litige », la couleur ne porte pas seule
    // l'information.
    final background = attention
        ? cs.warningLight
        : cs.onPrimary.withValues(alpha: 0.14);
    final labelColor = attention
        ? cs.onSurfaceVariant
        : cs.onPrimary.withValues(alpha: 0.85);
    final amountColor = attention ? cs.onSurface : cs.onPrimary;
    return Semantics(
      container: true,
      label: l.moneyAmountsSemantics(label, formatAmounts(shown)),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.sm),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(DonyRadius.md - 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                style: tt.bodySmall?.copyWith(color: labelColor),
              ),
              const SizedBox(height: DonySpacing.xxs),
              for (final a in shown)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatMoney(a.amount, a.currency),
                    style: tt.titleMedium?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w700,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
