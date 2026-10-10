import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/payments/money/bloc/money_schedule.dart';
import 'package:dony/features/payments/money/data/models/money_overview_model.dart';
import 'package:dony/features/payments/money/presentation/money_labels.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_amount_lines.dart';
import 'package:dony/features/payments/money/presentation/widgets/money_parcel_line.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Compteurs textuels d'un trajet, dans l'ordre de la barre :
/// « 2 versés · 1 livré · 3 en séquestre · 1 en litige ».
List<({TripSegment segment, String text})> tripCounters(
  MoneyTrip trip,
  AppLocalizations l,
) {
  int count(bool Function(MoneyItemModel) test) =>
      trip.items.where(test).length;
  final refunds = count(
    (i) =>
        i.state == MoneyState.refundPending ||
        i.state == MoneyState.refundedRecently,
  );
  final disputes = count((i) => i.state == MoneyState.inDispute);
  final reviews = count((i) => i.state == MoneyState.onHold);
  final cash = count((i) => i.state == MoneyState.cash);
  return [
    if (trip.count(TripSegment.paid) > 0)
      (
        segment: TripSegment.paid,
        text: l.moneyTripPaid(trip.count(TripSegment.paid)),
      ),
    if (trip.count(TripSegment.delivered) > 0)
      (
        segment: TripSegment.delivered,
        text: l.moneyTripDelivered(trip.count(TripSegment.delivered)),
      ),
    if (trip.count(TripSegment.escrow) > 0)
      (
        segment: TripSegment.escrow,
        text: l.moneyTripEscrow(trip.count(TripSegment.escrow)),
      ),
    if (disputes > 0)
      (segment: TripSegment.dispute, text: l.moneyTripDispute(disputes)),
    if (reviews > 0)
      (segment: TripSegment.dispute, text: l.moneyTripReview(reviews)),
    if (cash > 0) (segment: TripSegment.other, text: l.moneyTripCash(cash)),
    if (refunds > 0)
      (segment: TripSegment.other, text: l.moneyTripRefund(refunds)),
  ];
}

Color tripSegmentColor(TripSegment s, ColorScheme cs) => switch (s) {
  TripSegment.paid => cs.success,
  TripSegment.delivered => cs.primary,
  TripSegment.escrow => cs.outline,
  TripSegment.dispute => cs.warning,
  TripSegment.other => cs.onSurfaceVariant.withValues(alpha: 0.3),
};

/// Carte d'un trajet sur « Mes trajets » (FLUTTER-HV, écran D) : villes,
/// date, nombre de colis, total par devise, barre d'avancement segmentée
/// (proportionnelle au nombre de colis) et compteurs. Repliable : dépliée,
/// elle liste les colis ; un tap sur un colis l'ouvre.
class MoneyTripCard extends StatelessWidget {
  const MoneyTripCard({
    super.key,
    required this.trip,
    required this.expanded,
    required this.onToggle,
    required this.onOpenParcel,
  });

  final MoneyTrip trip;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<MoneyItemModel> onOpenParcel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final route = routeOf(trip.departureCity, trip.arrivalCity) ?? '';
    final parcels = l.moneyParcelCount(trip.items.length);
    final date = trip.date;
    final meta = date == null ? parcels : '${shortDate(date, l)} · $parcels';
    final counters = tripCounters(trip, l);
    final hasAttention = trip.count(TripSegment.dispute) > 0;

    final header = Semantics(
      button: true,
      onTapHint: expanded ? l.moneyTripCollapseHint : l.moneyTripExpandHint,
      child: DonyPressable(
        onTap: onToggle,
        scale: 0.98,
        // Fond transparent opaque au toucher : un tap entre la barre et les
        // compteurs replie ou déplie aussi la carte.
        child: Container(
          key: Key('money-trip-header-${trip.key}'),
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.base,
            DonySpacing.md + 2,
            DonySpacing.md,
            DonySpacing.md + 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(route, style: tt.titleLarge),
                        const SizedBox(height: DonySpacing.xxs),
                        Text(
                          meta,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  MoneyAmountLines(
                    amounts: trip.totals,
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: DonySpacing.xs),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 22,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DonySpacing.md - 2),
              Semantics(
                container: true,
                label: l.moneyTripSemantics(
                  route,
                  parcels,
                  counters.map((c) => c.text).join(', '),
                ),
                child: ExcludeSemantics(child: _ProgressBar(trip: trip)),
              ),
              const SizedBox(height: DonySpacing.md - 2),
              ExcludeSemantics(
                child: Wrap(
                  spacing: DonySpacing.md,
                  runSpacing: DonySpacing.xs,
                  children: [
                    for (final c in counters)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: tripSegmentColor(c.segment, cs),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: DonySpacing.xs),
                          Text(
                            c.text,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontFeatures: kTabularFigures,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Container(
      key: Key('money-trip-${trip.key}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(
          color: hasAttention ? cs.warning.withValues(alpha: 0.45) : cs.outline,
        ),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            if (expanded) ...[
              Divider(height: 1, thickness: 1, color: cs.outline),
              for (var i = 0; i < trip.items.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, color: cs.outlineVariant),
                _row(trip.items[i], l),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(MoneyItemModel item, AppLocalizations l) {
    final state = shortStateFor(item, l);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.xs),
      child: MoneyParcelLine(
        item: item,
        onTap: () => onOpenParcel(item),
        details: [?item.counterpartyName],
        status: state.text,
        tone: state.tone,
      ),
    );
  }
}

/// Barre segmentée, une part par catégorie, proportionnelle au nombre de
/// colis : versés, livrés, séquestre, litige, puis le reste (espèces,
/// remboursement).
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.trip});

  final MoneyTrip trip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = [
      for (final s in TripSegment.values)
        if (trip.count(s) > 0) (segment: s, flex: trip.count(s)),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.xs),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                flex: parts[i].flex,
                child: ColoredBox(
                  key: Key('money-bar-${parts[i].segment.name}'),
                  color: tripSegmentColor(parts[i].segment, cs),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
