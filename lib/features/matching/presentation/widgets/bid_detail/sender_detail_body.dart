import 'dart:async';

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
///
/// ## Animations
/// Le stagger d'entrée (fadeIn + slideY décalé de 60 ms × index) est joué
/// **une seule fois** grâce au flag [_SenderDetailBodyState._playEntrance].
/// Les rebuilds suivants (polling toutes les 10 s du parent) rendent les
/// cartes sans re-déclencher l'animation — flag passé à `false` après la
/// durée totale du stagger, sans `setState` (pas de rebuild superflu).
class SenderDetailBody extends StatefulWidget {
  final BidModel bid;

  const SenderDetailBody({super.key, required this.bid});

  @override
  State<SenderDetailBody> createState() => _SenderDetailBodyState();
}

class _SenderDetailBodyState extends State<SenderDetailBody> {
  /// `true` uniquement lors du premier build : déclenche le stagger d'entrée.
  ///
  /// Passé à `false` après la durée totale du stagger (sans [setState] pour
  /// ne pas provoquer un rebuild parasite). Le prochain rebuild naturel du
  /// parent (polling 10 s → BidDetailLoaded) lira ce flag à `false` et
  /// affichera les cartes directement, sans rejouer l'animation.
  bool _playEntrance = true;

  /// Timer utilisé pour désactiver le stagger après la durée totale.
  /// Annulé dans [dispose] pour éviter les timers pendants en test.
  Timer? _entranceTimer;

  /// Statuts où le voyageur est connu (carte voyageur affichée)
  /// et où le suivi est disponible (actions rapides affichées).
  static const _activeStatuses = <String>{
    'ACCEPTED',
    'HANDED_OVER',
    'IN_TRANSIT',
    'COMPLETED',
    'DELIVERED',
  };

  @override
  void initState() {
    super.initState();
    // Durée totale = délai max (60 ms × 7 pour 8 enfants, index 0–7)
    // + durée fadeIn (300 ms) + marge (50 ms).
    // Après ce délai, le flag est mis à false SANS setState : on ne veut pas
    // déclencher un rebuild ici, juste que le prochain rebuild (polling parent)
    // saute le stagger.
    const total = Duration(milliseconds: 60 * 7 + 300 + 50);
    _entranceTimer = Timer(total, () {
      _playEntrance = false;
    });
  }

  @override
  void dispose() {
    _entranceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final status = widget.bid.status;

    final children = <Widget>[
      // index 0 — ColisBillet possède déjà son propre .animate().fadeIn().slideY()
      // en interne (colis_billet.dart:53). On ne lui applique PAS le stagger ici
      // pour éviter une double animation (fade × fade + slide × slide).
      ColisBillet(bid: widget.bid, isSender: true),
      SenderHeroCard(bid: widget.bid),
      if (_activeStatuses.contains(status))
        VoyageurContactCard(bid: widget.bid),
      ColisDestinataireCard(bid: widget.bid),
      PaiementCard(bid: widget.bid),
      if (_activeStatuses.contains(status)) QuickActionsRow(bid: widget.bid),
      DetailsAccordion(bid: widget.bid),
      if (status == 'COMPLETED' && widget.bid.senderHasRated)
        const RatingDoneBadge(),
    ];

    // Stagger d'entrée : joué une seule fois (flag _playEntrance).
    // index 0 (ColisBillet) est exclu du stagger car il anime déjà en interne.
    // Les autres enfants entrent en fondu + glissement, décalés de 60 ms × i.
    final staggered = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        staggered.add(const SizedBox(height: DonySpacing.base));
      }

      // ColisBillet (index 0) : pas de stagger — son animation interne suffit.
      // Autres cartes : stagger uniquement lors du premier affichage.
      final child = children[i];
      if (_playEntrance && i > 0) {
        staggered.add(
          child
              .animate()
              .fadeIn(duration: 300.ms, delay: (60 * i).ms)
              .slideY(
                begin: 0.04,
                curve: Curves.easeOutCubic,
                delay: (60 * i).ms,
              ),
        );
      } else {
        staggered.add(child);
      }
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
            Flexible(
              child: Text(
                'Évaluation envoyée',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
