import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/money/bloc/money_schedule.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/money_labels.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_amount_lines.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_parcel_line.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Un groupe de « Prochains versements » (FLUTTER-HV, écran F) : en-tête
/// (échéance et total par devise) puis, selon le groupe, une ligne par colis
/// ou le résumé d'un trajet avec son lien « Détail des N colis ».
class MoneyPayoutGroup extends StatelessWidget {
  const MoneyPayoutGroup({
    super.key,
    required this.group,
    required this.onOpenParcel,
    required this.onOpenTrip,
  });

  final PayoutGroup group;
  final ValueChanged<MoneyItemModel> onOpenParcel;
  final ValueChanged<MoneyTrip> onOpenTrip;

  String _title(AppLocalizations l) {
    switch (group.kind) {
      case PayoutGroupKind.inProgress:
        return l.moneyGroupInProgress;
      case PayoutGroupKind.dated:
        return dayDate(group.date!, l);
      case PayoutGroupKind.trip:
        final first = group.items.first;
        final route = routeOf(first.departureCity, first.arrivalCity) ?? '';
        final date = group.date;
        return date == null
            ? route
            : l.moneyGroupTrip(shortDate(date, l), route);
      case PayoutGroupKind.dispute:
        return l.moneyGroupDispute;
      case PayoutGroupKind.review:
        return l.moneyGroupReview;
    }
  }

  String? _lineStatus(AppLocalizations l) => switch (group.kind) {
    PayoutGroupKind.inProgress => l.moneyLineInProgress,
    PayoutGroupKind.dated => l.moneyLineAuto,
    PayoutGroupKind.dispute => l.moneyLineDispute,
    PayoutGroupKind.review => l.moneyLineReview,
    PayoutGroupKind.trip => null,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final attention =
        group.kind == PayoutGroupKind.dispute ||
        group.kind == PayoutGroupKind.review;
    final accent = switch (group.kind) {
      PayoutGroupKind.inProgress || PayoutGroupKind.dated => cs.success,
      PayoutGroupKind.trip => cs.primary,
      PayoutGroupKind.dispute || PayoutGroupKind.review => cs.warning,
    };
    final headerStyle = tt.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );
    final title = _title(l);

    final header = Semantics(
      header: true,
      label: l.moneyAmountsSemantics(title, formatAmounts(group.totals)),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: DonySpacing.sm - 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5, right: DonySpacing.sm),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(child: Text(title, style: headerStyle)),
              const SizedBox(width: DonySpacing.sm),
              MoneyAmountLines(amounts: group.totals, style: headerStyle),
            ],
          ),
        ),
      ),
    );

    final background = attention ? cs.warningLight : cs.surface;
    final border = attention ? cs.warning.withValues(alpha: 0.35) : cs.outline;
    final List<Widget> body;
    if (group.kind == PayoutGroupKind.trip) {
      final trip = group.trip;
      body = [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: DonySpacing.md - 2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.moneyTripGroupBody(group.items.length),
                  style: tt.bodyMedium,
                ),
              ),
              const SizedBox(width: DonySpacing.sm),
              MoneyAmountLines(
                amounts: group.totals,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        if (trip != null) ...[
          Divider(height: 1, thickness: 1, color: cs.outlineVariant),
          Semantics(
            link: true,
            child: DonyPressable(
              onTap: () => onOpenTrip(trip),
              scale: 0.98,
              child: Container(
                key: Key('money-trip-link-${trip.key}'),
                color: Colors.transparent,
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: DonySpacing.md,
                  vertical: DonySpacing.sm,
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  l.moneyTripGroupDetails(trip.items.length),
                  style: tt.bodyMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ];
    } else {
      final status = _lineStatus(l);
      body = [
        for (var i = 0; i < group.items.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: border),
          MoneyParcelLine(
            item: group.items[i],
            onTap: () => onOpenParcel(group.items[i]),
            details: [
              ?routeOf(
                group.items[i].departureCity,
                group.items[i].arrivalCity,
              ),
            ],
            status: status,
            tone: attention ? MoneyTone.attention : MoneyTone.neutral,
          ),
        ],
      ];
    }

    return Column(
      key: Key(
        'money-group-${group.kind.name}-${group.trip?.key ?? group.date?.toIso8601String() ?? ''}',
      ),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(DonyRadius.md),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: body,
          ),
        ),
      ],
    );
  }
}
