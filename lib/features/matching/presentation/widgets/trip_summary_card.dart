import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Résumé du trajet du voyageur : colis en sa possession, kilos transportés et
/// gain estimé (net, dans la devise du trajet). Le gain n'apparaît que s'il
/// est positif : les colis payés en espèces comptent pour 0.
///
/// « Voir mes colis » mène au même écran que la tuile « Colis » de la grille
/// d'actions (`/announcements/:id/bids`).
class TripSummaryCard extends StatelessWidget {
  const TripSummaryCard({
    super.key,
    required this.announcementId,
    required this.summary,
  });

  final String announcementId;
  final TripParcelsSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final kg = NumberFormat('#,##0.#', l.localeName).format(summary.totalKg);
    return Container(
      key: const Key('trip-summary-card'),
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.tripSummaryTitle,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: DonySpacing.sm),
          Text(l.tripSummaryParcels(summary.count), style: tt.bodyMedium),
          const SizedBox(height: DonySpacing.xs),
          Text(l.tripSummaryWeight(kg), style: tt.bodyMedium),
          if (summary.netAmount > 0) ...[
            const SizedBox(height: DonySpacing.md),
            Text(
              l.tripSummaryEarningsLabel,
              style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text(
              CurrencyFormatter.format(
                summary.netAmount,
                SupportedCurrency.fromCodeOrDefault(summary.currency),
              ),
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              l.tripSummaryEarningsNote,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: DonySpacing.md),
          DonyButton(
            key: const Key('trip-summary-view-parcels'),
            label: l.tripSummaryViewParcels,
            variant: DonyButtonVariant.secondary,
            onPressed: () => context.push(
              '/announcements/$announcementId/bids',
              extra: <String, dynamic>{'title': l.tripOwnerParcelsTile},
            ),
          ),
        ],
      ),
    );
  }
}
