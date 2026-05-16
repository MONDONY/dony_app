import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:flutter/material.dart';

// 1 − 12% de commission dony
const _kTravelerShareRate = 0.88;

/// Carte affichant la libération des fonds au voyageur (statut COMPLETED).
///
/// Correspond à l'ancienne classe privée `_PaymentReleaseCard` de
/// `bid_detail_screen.dart`.
class PaymentReleaseCard extends StatelessWidget {
  final BidModel bid;

  const PaymentReleaseCard({super.key, required this.bid});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fonds libérés à ${bid.travelerName ?? 'le voyageur'}',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                ),
                Text(
                  'Reçu disponible · ${bid.pricePerKg != null ? (bid.pricePerKg! * bid.weightKg * _kTravelerShareRate).toStringAsFixed(2) : '—'} €',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // "Reçu" chip
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.md,
              vertical: DonySpacing.xs,
            ),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: cs.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: DonySpacing.xs),
                Text(
                  'Reçu',
                  style: tt.labelSmall?.copyWith(
                    color: cs.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
