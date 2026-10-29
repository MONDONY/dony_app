import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/cancellation/presentation/widgets/delivery_noshow_cta_cell.dart';
import 'package:dony/features/cancellation/presentation/widgets/delivery_noshow_procedure_card.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/arrival_instructions_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/paiement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/prevenir_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_tile_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/trip_reschedule_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/voyageur_contact_card.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:dony/features/matching/presentation/widgets/tool_status_badge.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Corps de l'écran « Détail d'envoi » (vue expéditeur).
///
/// Ordre : billet de colis ; « À traiter » (cartes qui attendent une réponse,
/// seulement s'il y en a) ; carte voyageur ; carte paiement ; grille de tuiles
/// « Votre envoi » (Prévenir, Suivi ou Lieux, Colis et destinataire, Plus de
/// détails), chacune ouvrant un bottom sheet ([openSenderTileSheet]) ; cellule
/// « le voyageur ne livre pas » ; badge d'évaluation si déjà notée.
///
/// Requiert les BLoCs ambiants suivants (fournis par l'écran parent) :
///   - [CancellationBloc] (via [SenderHeroCard]),
///   - [ConversationOpenBloc] (via [VoyageurContactCard]),
///   - [TrackingBloc] / [BidBloc] (via le talon QR du billet et les sheets).
///
/// ## Animations
/// Le stagger d'entrée (fadeIn + slideY décalé de 60 ms × index) est joué
/// **une seule fois** grâce au flag [_SenderDetailBodyState._playEntrance].
/// Les rebuilds suivants (polling du parent) rendent les cartes sans
/// re-déclencher l'animation — flag passé à `false` après la durée totale du
/// stagger, sans `setState` (pas de rebuild superflu).
class SenderDetailBody extends StatefulWidget {
  final BidModel bid;

  /// Ouvert depuis la notification `BID_SUPPLEMENT_REQUESTED`
  /// (`?action=supplement`) : l'encart du supplément est amené à l'écran au
  /// premier affichage où il existe.
  final bool focusSupplement;

  /// Ouvert depuis une notification de modification
  /// (`?action=amendment`).
  final bool focusAmendment;

  const SenderDetailBody({
    super.key,
    required this.bid,
    this.focusSupplement = false,
    this.focusAmendment = false,
  });

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

  /// Statuts où les instructions de retrait s'affichent.
  static const _activeStatuses = <String>{
    'ACCEPTED',
    'HANDED_OVER',
    'IN_TRANSIT',
    'ARRIVED',
    'COMPLETED',
    'DELIVERED',
  };

  /// Statuts où la tuile Suivi porte la pastille « Étape en cours ».
  static const _inProgressStatuses = <String>{
    'HANDED_OVER',
    'IN_TRANSIT',
    'ARRIVED',
  };

  @override
  void initState() {
    super.initState();
    // Durée totale = délai max (60 ms × 7, index plafonné) + durée fadeIn
    // (300 ms) + marge (50 ms).
    // Après ce délai, le flag est mis à false SANS setState : on ne veut pas
    // déclencher un rebuild ici, juste que le prochain rebuild (polling parent)
    // saute le stagger.
    const total = Duration(milliseconds: 60 * 7 + 300 + 50);
    _entranceTimer = Timer(total, () {
      _playEntrance = false;
    });
  }

  /// Encart du supplément, cible de [SenderDetailBody.focusSupplement].
  final _supplementKey = GlobalKey();
  bool _supplementFocused = false;

  /// Encart de la modification, cible de [SenderDetailBody.focusAmendment].
  final _amendmentKey = GlobalKey();
  bool _amendmentFocused = false;

  @override
  void dispose() {
    _entranceTimer?.cancel();
    super.dispose();
  }

  /// Amène l'encart du supplément à l'écran une seule fois, dès qu'il existe
  /// (le colis arrive souvent après le premier affichage, lien profond).
  void _maybeFocusSupplement() {
    if (!widget.focusSupplement ||
        _supplementFocused ||
        !SupplementSenderCard.shouldShow(widget.bid)) {
      return;
    }
    _supplementFocused = true;
    _scrollTo(_supplementKey);
  }

  /// Même chose pour la carte de la modification (`?action=amendment`).
  void _maybeFocusAmendment() {
    if (!widget.focusAmendment ||
        _amendmentFocused ||
        !AmendmentSenderCard.shouldShow(widget.bid)) {
      return;
    }
    _amendmentFocused = true;
    _scrollTo(_amendmentKey);
  }

  void _scrollTo(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    });
  }

  /// Tuile de la grille « Votre envoi ». Le tap ouvre le sheet avec le contexte
  /// de ce `State` (jamais celui de la tuile) : la liste des tuiles change au
  /// rafraîchissement du colis, et le sheet ne doit pas dépendre d'une tuile
  /// qui disparaît (frise, modification du colis ouvertes après la fermeture).
  Widget _tileFor(SenderTile tile) {
    final bid = widget.bid;
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final summary = SenderHeroCard.statusLine(context, bid);
    final weight = bid.displayWeightKg;
    final recipient = bid.recipientName?.trim();

    final (iconName, label, color) = switch (tile) {
      SenderTile.prevenir => (
        'message-circle',
        l.recipientNotifyTitle(PrevenirDestinataire.displayName(l, bid)),
        cs.primary,
      ),
      SenderTile.suivi => ('route', l.senderTileSuivi, cs.secondary),
      SenderTile.lieux => ('map-pin', l.senderTileLieux, cs.secondary),
      SenderTile.colis => ('package', l.senderTileColis, cs.primary),
      SenderTile.details => ('file-text', l.bidDetailMoreDetails, cs.primary),
    };

    final subtitle = switch (tile) {
      SenderTile.prevenir =>
        PrevenirDestinataire.withCode(bid)
            ? l.senderTilePrevenirCode
            : l.senderTilePrevenirLink,
      SenderTile.suivi || SenderTile.lieux => summary,
      SenderTile.colis =>
        weight == null
            ? null
            : (recipient == null || recipient.isEmpty)
            ? formatWeightKg(l, weight)
            : l.senderTileColisSubtitle(formatWeightKg(l, weight), recipient),
      SenderTile.details => l.senderTileDetailsSubtitle,
    };

    final badge = switch (tile) {
      SenderTile.prevenir when PrevenirDestinataire.withCode(bid) => _badge(
        l.senderTileBadgeCodeReady,
        ToolStatusTone.ready,
      ),
      SenderTile.suivi when _inProgressStatuses.contains(bid.status) => _badge(
        l.senderTileBadgeCurrentStep,
        ToolStatusTone.inProgress,
      ),
      _ => null,
    };

    return DonyActionTile(
      key: Key('sender-tile-${tile.name}'),
      iconName: iconName,
      label: label,
      subtitle: subtitle,
      color: color,
      badge: badge,
      onTap: () => unawaited(openSenderTileSheet(context, bid, tile)),
    );
  }

  Widget _badge(String label, ToolStatusTone tone) => ToolStatusBadge(
    ready: tone == ToolStatusTone.ready,
    tone: tone,
    label: label,
    semanticsLabel: label,
  );

  @override
  Widget build(BuildContext context) {
    final h = DonyLayout.hPadding(context);
    final status = widget.bid.status;
    final l = context.l10n;
    _maybeFocusSupplement();
    _maybeFocusAmendment();

    final bid = widget.bid;

    // Supplément et modification : sous « À traiter » tant qu'ils attendent
    // une réponse, sinon simples informations juste après, sans titre. La clé
    // de focus suit la carte d'un côté comme de l'autre.
    final supplement = SupplementSenderCard.shouldShow(bid)
        ? SupplementSenderCard(key: _supplementKey, bid: bid)
        : null;
    final supplementReply =
        supplement != null && SupplementSenderCard.needsReply(bid);
    final amendment = AmendmentSenderCard.shouldShow(bid)
        ? AmendmentSenderCard(key: _amendmentKey, bid: bid)
        : null;
    final amendmentReply =
        amendment != null && AmendmentSenderCard.needsReply(bid);

    // « À traiter » ne réunit que ce qui attend une réponse ou une action.
    final actions = <Widget>[
      if (SenderHeroCard.hasAction(bid)) SenderHeroCard(bid: bid),
      if (supplementReply) supplement,
      if (amendmentReply) amendment,
      if (TripRescheduleCard.shouldShow(bid))
        TripRescheduleCard(bid: bid, isSender: true),
      // Le destinataire a refusé : renvoyer le message n'aurait pas de sens,
      // il faut en désigner un autre.
      if (PrevenirDestinataire.showsDeclined(bid))
        RecipientDeclinedCard(bid: bid),
      // Destinataire absent signalé par le voyageur (FLUTTER-E2) : nouveau
      // rendez-vous, changement de destinataire, garde, colis non réclamé.
      if (DeliveryNoShowProcedureCard.shouldShow(bid, isSender: true))
        DeliveryNoShowProcedureCard(bid: bid, isSender: true),
    ];

    final infos = <(String, Widget)>[
      if (supplement != null && !supplementReply)
        ('info-supplement', supplement),
      if (amendment != null && !amendmentReply) ('info-amendment', amendment),
      // Consignes de retrait : hors du hero, qui les masquait dès qu'une
      // contestation, une absence ou la livraison prenait la place.
      if (_activeStatuses.contains(status) &&
          ArrivalInstructionsCard.hasText(bid.arrivalInstructions))
        (
          'info-arrival',
          ArrivalInstructionsCard(instructions: bid.arrivalInstructions!),
        ),
    ];

    // Chaque section porte une clé : l'apparition ou la disparition de
    // « À traiter » ne remonte ni le voyageur, ni le paiement, ni la grille.
    final children = <(String, Widget)>[
      // index 0 — ColisBillet possède déjà son propre .animate().fadeIn().slideY()
      // en interne (colis_billet.dart:53). On ne lui applique PAS le stagger ici
      // pour éviter une double animation (fade × fade + slide × slide).
      ('billet', ColisBillet(bid: bid, isSender: true)),
      if (actions.isNotEmpty)
        ('todo', _Section(title: l.bidDetailSectionTodo, children: actions)),
      ...infos,
      // Profil du voyageur à tous les statuts ; les boutons de contact
      // n'apparaissent qu'une fois la demande acceptée.
      ('voyageur', VoyageurContactCard(bid: bid)),
      ('paiement', PaiementCard(bid: bid)),
      (
        'shipment',
        _Section(
          title: l.bidDetailSectionShipment,
          spacing: DonySpacing.md,
          children: [
            DonyActionTileGrid(
              tiles: [for (final tile in senderTilesFor(bid)) _tileFor(tile)],
            ),
          ],
        ),
      ),
      if (DeliveryNoShowCtaCell.shouldShow(bid))
        ('noshow-cta', DeliveryNoShowCtaCell(bid: bid, isSender: true)),
      if (status == 'COMPLETED' && bid.senderHasRated)
        ('rating', const RatingDoneBadge()),
    ];

    // Stagger d'entrée : joué une seule fois (flag _playEntrance).
    // index 0 (ColisBillet) est exclu du stagger car il anime déjà en interne.
    // Les autres enfants entrent en fondu + glissement, décalés de 60 ms × i.
    final staggered = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      final (name, child) = children[i];
      final Widget shown;
      if (_playEntrance && i > 0) {
        // Délai plafonné à l'index 7 : la durée totale du timer ci-dessus
        // reste vraie quel que soit le nombre de cartes.
        final delay = (60 * (i > 7 ? 7 : i)).ms;
        shown = child
            .animate()
            .fadeIn(duration: 300.ms, delay: delay)
            .slideY(begin: 0.04, curve: Curves.easeOutCubic, delay: delay);
      } else {
        shown = child;
      }
      staggered.add(KeyedSubtree(key: ValueKey(name), child: shown));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(h, DonySpacing.lg, h, 100),
      child: DonyLayout.constrained(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DonySpacing.base,
          children: staggered,
        ),
      ),
    );
  }
}

/// Section de la fiche : un titre puis ses contenus, séparés de [spacing].
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.spacing = DonySpacing.base,
  });

  final String title;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: DonySpacing.md),
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: spacing),
        children[i],
      ],
    ],
  );
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
            DonyIcon('circle-check', size: 16, color: cs.primary),
            const SizedBox(width: DonySpacing.xs),
            Flexible(
              child: Text(
                context.l10n.bidDetailRatingSentBadge,
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
