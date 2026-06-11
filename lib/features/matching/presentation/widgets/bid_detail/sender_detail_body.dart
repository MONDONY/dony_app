import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/details_accordion.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/paiement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/quick_actions_row.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/voyageur_contact_card.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Corps de l'écran « Détail d'envoi » (vue expéditeur).
///
/// Compose la nouvelle vue redesignée : billet de colis, hero contextuel,
/// carte voyageur (si le voyageur est connu), carte colis & destinataire,
/// carte paiement, actions rapides de suivi, accordéon de détails, et badge
/// d'évaluation si déjà notée.
///
/// Requiert les BLoCs ambiants suivants (fournis par l'écran parent) :
///   - [CancellationBloc] (via [SenderHeroCard]),
///   - [ConversationOpenBloc] (via [VoyageurContactCard]),
///   - [TrackingBloc] / [BidBloc] (via le talon QR du billet).
class SenderDetailBody extends StatelessWidget {
  final BidModel bid;

  const SenderDetailBody({super.key, required this.bid});

  /// Statuts où le voyageur est connu (carte voyageur affichée).
  static const _voyageurStatuses = <String>{
    'ACCEPTED',
    'HANDED_OVER',
    'IN_TRANSIT',
    'COMPLETED',
    'DELIVERED',
  };

  /// Statuts où le suivi est disponible (actions rapides affichées).
  static const _suiviStatuses = _voyageurStatuses;

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final status = bid.status;

    final children = <Widget>[
      ColisBillet(bid: bid, isSender: true),
      SenderHeroCard(bid: bid),
      if (_voyageurStatuses.contains(status)) VoyageurContactCard(bid: bid),
      ColisDestinataireCard(bid: bid),
      PaiementCard(bid: bid),
      if (_suiviStatuses.contains(status)) QuickActionsRow(bid: bid),
      DetailsAccordion(bid: bid),
      if (status == 'COMPLETED' && bid.senderHasRated) const RatingDoneBadge(),
    ];

    // Stagger d'entrée : chaque enfant entre en fondu + glissement, décalé de
    // 60 ms × index. Séparés par un espace vertical constant.
    final staggered = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        staggered.add(const SizedBox(height: DonySpacing.base));
      }
      staggered.add(
        children[i]
            .animate()
            .fadeIn(duration: 300.ms, delay: (60 * i).ms)
            .slideY(
              begin: 0.04,
              curve: Curves.easeOutCubic,
              delay: (60 * i).ms,
            ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(h, DonySpacing.lg, h, 100),
      child: DonyLayout.constrained(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: staggered,
        ),
      ),
    );
  }
}

// ── Badge « Évaluation envoyée » ───────────────────────────────────────────────

/// Pill affichée à l'expéditeur lorsque l'évaluation du voyageur a déjà été
/// soumise (`bid.senderHasRated == true`, statut COMPLETED).
class RatingDoneBadge extends StatelessWidget {
  const RatingDoneBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.base,
          vertical: DonySpacing.sm,
        ),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(DonyRadius.card),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
            const SizedBox(width: DonySpacing.xs),
            Text(
              'Évaluation envoyée',
              style: tt.bodyMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
