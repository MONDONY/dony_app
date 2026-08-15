import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Carte affichant le dépôt du colis (lieu, date limite, confirmation voyageur).
///
/// Correspond à l'ancienne classe privée `_HandoverCard` de
/// `bid_detail_screen.dart`.
class HandoverCard extends StatelessWidget {
  final BidModel bid;

  const HandoverCard({super.key, required this.bid});

  @override
  Widget build(BuildContext context) {
    return DetailCard(
      title: 'Dépôt du colis',
      child: Column(
        children: [
          InfoRow(label: 'Lieu', value: bid.handoverLocation ?? '-'),
          if (bid.handoverDeadline != null) ...[
            const SizedBox(height: DonySpacing.sm),
            InfoRow(
              label: 'Date limite',
              value: DateFormat(
                'dd/MM/yyyy',
              ).format(bid.handoverDeadline!.toLocal()),
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
