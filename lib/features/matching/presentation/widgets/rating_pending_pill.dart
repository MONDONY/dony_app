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

/// Fenêtre de notation après la livraison (back `RatingService`,
/// `RATING_WINDOW_DAYS`) : passé ce délai, la note répond 422
/// `rating-window-expired`.
const kBidRatingWindow = Duration(days: 7);

/// Fin de la fenêtre de notation de [bid] : le back la mesure sur
/// `updatedAt` du colis (refus quand `updatedAt` est avant `now - 7 j`),
/// l'app fait de même.
DateTime bidRatingDeadline(BidModel bid) => bid.updatedAt.add(kBidRatingWindow);

/// La note de [bid] est encore acceptée par le back à [now] :
/// `updatedAt + 7 j` pas encore dépassé (même borne que `RatingService`,
/// qui refuse seulement `updatedAt < now - 7 j`).
bool bidRatingWindowOpen(BidModel bid, DateTime now) =>
    !now.isAfter(bidRatingDeadline(bid));

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
