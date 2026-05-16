import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Carte affichant la fenêtre de remise (lieu, début, fin, confirmation voyageur).
///
/// Correspond à l'ancienne classe privée `_HandoverCard` de
/// `bid_detail_screen.dart`.
class HandoverCard extends StatelessWidget {
  final BidModel bid;

  const HandoverCard({super.key, required this.bid});

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      title: 'Fenêtre de remise',
      child: Column(
        children: [
          InfoRow(label: 'Lieu', value: bid.handoverLocation ?? '—'),
          if (bid.handoverWindowStart != null) ...[
            const SizedBox(height: DonySpacing.sm),
            InfoRow(
              label: 'Début',
              value: DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(bid.handoverWindowStart!.toLocal()),
            ),
          ],
          if (bid.handoverWindowEnd != null) ...[
            const SizedBox(height: DonySpacing.sm),
            InfoRow(
              label: 'Fin',
              value: DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(bid.handoverWindowEnd!.toLocal()),
            ),
          ],
          const SizedBox(height: DonySpacing.sm),
          InfoRow(
            label: 'Présence confirmée',
            value: bid.voyageurConfirmed ? 'Oui ✓' : 'Non encore',
          ),
        ],
      ),
    );
  }
}
