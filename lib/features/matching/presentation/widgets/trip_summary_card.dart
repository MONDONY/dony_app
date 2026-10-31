import 'package:dony/core/currency/currency_formatter.dart';
import 'package:dony/core/currency/supported_currency.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/announcement_model.dart';
import 'package:dony/features/matching/data/models/trip_parcels_summary.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Carte « argent » du trajet du voyageur, comme la carte de gain de la
/// fiche colis : gain estimé (net, dans la devise du trajet) en grand, puis
/// les colis en sa possession et les kilos transportés. Le gain n'apparaît
/// que s'il est positif (les colis payés en espèces comptent pour 0) : la
/// carte reste alors le résumé du trajet (colis et kilos).
///
/// Sans bouton : la liste des colis s'ouvre depuis la carte Colis (« Voir la
/// liste »).
class TripSummaryCard extends StatelessWidget {
  const TripSummaryCard({super.key, required this.summary});

  final TripParcelsSummary summary;

  /// La carte s'affiche pour le propriétaire confirmé quand le détail sert un
  /// résumé d'au moins un colis remis, en transit ou arrivé
  /// (`parcelsSummary`, servi au seul propriétaire).
  static bool shownFor({
    required bool isOwner,
    required AnnouncementModel trip,
  }) => isOwner && (trip.parcelsSummary?.count ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DetailCard(
      key: const Key('trip-summary-card'),
      title: summary.netAmount > 0
          ? l.tripSummaryEarningsLabel
          : l.tripSummaryTitle,
      child: TripGainContent(summary: summary),
    );
  }
}

/// Contenu de la carte de gain du trajet ([TripSummaryCard]), repris tel
/// quel par le sheet « Gain » de l'activité du trajet : gain estimé en grand
/// quand il est positif, colis en possession, kilos transportés, note sur le
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
