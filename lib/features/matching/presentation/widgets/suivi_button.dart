import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_timeline_bottom_sheet.dart';
import 'package:flutter/material.dart';

/// Bouton « Suivi du colis » — ouvre la feuille de suivi en temps réel.
///
/// Visible pour les statuts : ACCEPTED, HANDED_OVER, IN_TRANSIT,
/// COMPLETED et DELIVERED.
class SuiviButton extends StatelessWidget {
  final BidModel bid;

  const SuiviButton({super.key, required this.bid});

  String get _corridor {
    final dep = bid.departureCity ?? '';
    final arr = bid.arrivalCity ?? '';
    return dep.isNotEmpty && arr.isNotEmpty ? '$dep → $arr' : 'Suivi du colis';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => showTrackingTimelineSheet(
        context,
        bidId: bid.id,
        corridor: _corridor,
      ),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.base),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            // Leading icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(DonyRadius.sm),
              ),
              child: Icon(
                Icons.local_shipping_rounded,
                color: cs.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suivi du colis',
                    style: tt.titleSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Voir le détail et les photos',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Trailing chevron
            Icon(Icons.chevron_right_rounded, color: cs.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
