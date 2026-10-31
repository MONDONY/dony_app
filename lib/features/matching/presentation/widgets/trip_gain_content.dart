import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Détail du gain du trajet du voyageur, contenu du sheet « Gain » de
/// l'activité du trajet (`openTripActivitySheet`), comme la carte de gain de
/// la fiche colis : gain estimé (net, dans la devise du trajet) en grand
/// quand il est positif (les colis payés en espèces comptent pour 0), puis
/// les colis en sa possession, les kilos transportés et la note sur le
/// versement. Lecture seule.
class TripGainContent extends StatelessWidget {
  const TripGainContent({super.key, required this.summary});

  final TripParcelsSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final kg = NumberFormat('#,##0.#', l.localeName).format(summary.totalKg);
    final hasEarnings = summary.netAmount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasEarnings) ...[
          // Montant sur une ligne : il rétrécit plutôt que de passer à la
          // ligne à texte agrandi, comme la carte de gain de la fiche colis.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(
                summary.netAmount,
                SupportedCurrency.fromCodeOrDefault(summary.currency),
              ),
              key: const Key('trip-summary-earnings'),
              maxLines: 1,
              style: tt.titleLarge?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.xs),
        ],
        Text(l.tripSummaryParcels(summary.count), style: tt.bodyMedium),
        const SizedBox(height: DonySpacing.xxs),
        Text(l.tripSummaryWeight(kg), style: tt.bodyMedium),
        if (hasEarnings) ...[
          const SizedBox(height: DonySpacing.xs),
          Text(
            l.tripSummaryEarningsNote,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
