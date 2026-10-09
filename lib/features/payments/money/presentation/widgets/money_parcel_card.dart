import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/money_conditions.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_release_timeline.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Carte d'un colis dans « Mon argent » : code et trajet, contrepartie et
/// poids ou date, montant, frise de libération et phrase de condition. Les
/// colis en espèces et les remboursements s'affichent en carte compacte, sans
/// frise. Un tap ouvre le colis.
class MoneyParcelCard extends StatelessWidget {
  const MoneyParcelCard({super.key, required this.item, required this.onTap});

  final MoneyItemModel item;
  final VoidCallback onTap;

  String _title() {
    final route = [
      item.departureCity,
      item.arrivalCity,
    ].whereType<String>().join(' → ');
    return [
      item.trackingNumber,
      if (route.isNotEmpty) route,
    ].whereType<String>().join(' · ');
  }

  String? _subtitle(AppLocalizations l) {
    final weight = item.weightKg;
    final departure = item.departureDate;
    final String? detail;
    if (item.state == MoneyState.escrowed && departure != null) {
      detail = l.moneyItemDeparture(
        DateFormat.MMMd(l.localeName).format(departure),
      );
    } else if (weight != null) {
      detail = l.moneyItemWeight(
        NumberFormat.decimalPattern(l.localeName).format(weight),
      );
    } else if (departure != null) {
      detail = l.moneyItemDeparture(
        DateFormat.MMMd(l.localeName).format(departure),
      );
    } else {
      detail = null;
    }
    final parts = [item.counterpartyName, detail].whereType<String>();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final segments = timelineFor(item);
    final condition = conditionFor(item, l);
    final amount = item.amount;
    final subtitle = segments == null ? null : _subtitle(l);

    final conditionColor = switch (condition.tone) {
      ConditionTone.positive => cs.success,
      ConditionTone.attention => cs.onSurface,
      ConditionTone.neutral => cs.onSurfaceVariant,
    };

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _title(),
                style: tt.titleLarge?.copyWith(fontFeatures: _tabular),
              ),
              if (segments == null) ...[
                const SizedBox(height: 2),
                Text(
                  condition.text,
                  style: tt.bodySmall?.copyWith(color: conditionColor),
                ),
              ] else if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        if (amount != null) ...[
          const SizedBox(width: DonySpacing.sm),
          Text(
            formatMoney(amount, item.currency),
            style: tt.titleLarge?.copyWith(
              fontFeatures: _tabular,
              color: segments == null ? cs.onSurfaceVariant : cs.onSurface,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      onTapHint: l.moneyOpenParcelHint,
      child: DonyPressable(
        onTap: onTap,
        child: Container(
          key: Key('money-parcel-${item.bidId}'),
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: segments == null
              ? header
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: DonySpacing.md + 2),
                    MoneyReleaseTimeline(segments: segments),
                    const SizedBox(height: DonySpacing.md + 2),
                    Row(
                      children: [
                        if (condition.tone == ConditionTone.attention) ...[
                          Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: cs.warning,
                          ),
                          const SizedBox(width: DonySpacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            condition.text,
                            style: tt.bodyMedium?.copyWith(
                              color: conditionColor,
                              fontWeight:
                                  condition.tone == ConditionTone.neutral
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
