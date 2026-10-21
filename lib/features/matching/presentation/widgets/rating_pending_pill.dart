import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Colis livré dont la note n'est pas encore donnée par la partie qui regarde
/// la liste : l'expéditeur ([asSender]) note le voyageur, le voyageur note
/// l'expéditeur. Même règle que le bouton « Noter » du détail.
bool bidAwaitsRating(BidModel bid, {required bool asSender}) {
  final delivered = bid.status == 'COMPLETED' || bid.status == 'DELIVERED';
  if (!delivered) return false;
  return asSender ? !bid.senderHasRated : !bid.travelerHasRated;
}

/// Pastille « À noter » des cartes de colis (FLUTTER-P2) : rappel discret
/// d'une note en attente, la feuille de notation ne s'ouvrant plus d'elle-même
/// qu'une fois par colis.
class RatingPendingPill extends StatelessWidget {
  const RatingPendingPill({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.sm,
        vertical: DonySpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.warningLight,
        borderRadius: BorderRadius.circular(DonyRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('star-fill', size: 12, color: cs.warning),
          const SizedBox(width: DonySpacing.xxs),
          Text(
            context.l10n.ratingPendingPillLabel,
            style: tt.labelSmall?.copyWith(
              color: cs.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
