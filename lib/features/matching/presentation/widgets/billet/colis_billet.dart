import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_route.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_status_stamp.dart';
import 'package:dony/features/matching/presentation/widgets/billet/billet_talon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Carte billet de colis complète (boarding-pass metaphor).
///
/// Assemble l'en-tête YADONY, le corridor départ→arrivée, la zone dates,
/// la ligne de perforation et le talon d'action.
///
/// Le corridor, les dates et la perforation viennent de [BilletRoute],
/// partagé avec la fiche trajet vue par un expéditeur (FLUTTER-GG).
class ColisBillet extends StatelessWidget {
  final BidModel bid;
  final bool isSender;

  const ColisBillet({super.key, required this.bid, required this.isSender});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            boxShadow: DonyShadow.md,
          ),
          // overflow visible pour que les encoches de BilletPerforation mordent
          // dans les bords latéraux sans être clippées.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BilletHeader(bid: bid, isSender: isSender),
              BilletRoute(
                departureCity:
                    bid.departureCity ?? 'Paris', // i18n-ignore: nom propre
                arrivalCity:
                    bid.arrivalCity ?? 'Dakar', // i18n-ignore: nom propre
                departureDate: bid.departureDate,
                departureTime: bid.departureTime,
                arrivalDate: bid.arrivalDate,
                arrivalTime: bid.arrivalTime,
                notchColor: Theme.of(context).scaffoldBackgroundColor,
              ),
              BilletTalon(bid: bid, isSender: isSender),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

// ── En-tête ────────────────────────────────────────────────────────────────────

class _BilletHeader extends StatelessWidget {
  final BidModel bid;
  final bool isSender;
  const _BilletHeader({required this.bid, required this.isSender});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.base,
        DonySpacing.base,
        DonySpacing.base,
        DonySpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              context.l10n.ticketHeaderTagline,
              style: tt.bodySmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: DonySpacing.sm),
          BilletStatusStamp(
            status: bid.status,
            isSender: isSender,
            awaitingMyPayment: bid.isAwaitingSenderCardPayment,
          ),
        ],
      ),
    );
  }
}
