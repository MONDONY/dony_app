import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/presentation/widgets/delivery_noshow_cta_cell.dart';
import 'package:dony/features/cancellation/presentation/widgets/delivery_noshow_procedure_card.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/bid_detail_section.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/expediteur_contact_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_detail_body.dart'
    show RatingDoneBadge;
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/todo_tile_views.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_info_cards.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_sticky_bar.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_todo_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_todo_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_transport_section.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/trip_reschedule_card.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:dony/features/matching/presentation/widgets/tool_status_badge.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Corps de l'écran « Détail d'envoi » (vue voyageur).
///
/// Ordre : billet de colis ; hero sans titre quand il ne porte pas de bouton
/// (demande à décider, attente du paiement, absence signalée : les étapes du
/// transport n'ont plus de carte d'information, le footer les porte) ;
/// « À traiter » (ce qui attend un geste du voyageur, seulement s'il y a
/// quelque chose : les cartes d'alerte, hero à bouton puis modification à
/// bouton, puis la grille des tuiles des demandes qui attendent une réponse,
/// chacune ouvrant son bottom sheet par [openTravelerTodoSheet] : frais de
/// service du supplément à valider) ; cartes d'information sans titre
/// (attente du paiement, scan bloqué, verrou avant le départ, supplément et
/// modification qui n'attendent rien de lui, trajet reporté, procédure
/// « destinataire absent » dans tous ses états) ; expéditeur ; gain ; grille
/// de tuiles « Votre transport » (Lieux, Colis et destinataire, Plus de
/// détails), chacune ouvrant un bottom sheet ([TravelerTransportSection]) ;
/// badge d'évaluation si déjà notée.
///
/// Une carte qui change de section ne perd pas son état : la modification
/// porte une `GlobalKey` (cible du défilement `?action=amendment`), qui la
/// déplace de « À traiter » à l'information (ou l'inverse) SANS la remonter.
/// Son `State` est gardé, ses cubits ne sont pas recréés et
/// `bid_amendment_viewed` ne repart pas. Le supplément ne change plus de
/// section : tuile tant que ses frais attendent le voyageur (mesurée à
/// l'affichage de la tuile, `surface: tile`), carte d'information sinon (sa
/// `GlobalKey` reste la cible du défilement `?action=supplement`). Le hero,
/// sans clé, est remonté quand il gagne ou perd son bouton (choix assumé).
///
/// Une exception, la fin du stagger d'entrée : quand l'animation est retirée
/// (voir plus bas), toutes les sections sauf le billet et les deux cartes à
/// `GlobalKey` sont remontées UNE fois (le `Animate` qui les enveloppait
/// disparaît). Sans conséquence à ce moment (cartes juste affichées, rien
/// n'est encore saisi), et identique à la vue expéditeur.
///
/// Requiert les BLoCs ambiants suivants (fournis par l'écran parent) :
///   - [CancellationBloc] (via [TravelerHeroCard] et la procédure
///     « destinataire absent »),
///   - [ConversationOpenBloc] (via [ExpediteurContactCard]).
///
/// ## Animations
/// Le stagger d'entrée (fadeIn + slideY décalé de 60 ms × index) est joué
/// **une seule fois** grâce au flag [_TravelerDetailBodyState._playEntrance].
/// Les rebuilds suivants (polling du parent) rendent les cartes sans
/// re-déclencher l'animation — flag passé à `false` après la durée totale du
/// stagger, sans `setState` (pas de rebuild superflu).
class TravelerDetailBody extends StatefulWidget {
  final BidModel bid;

  /// Ouvert depuis une notification de supplément (`?action=supplement`) :
  /// au premier affichage où le supplément existe, le sheet de la tuile
  /// « Supplément de prix » s'ouvre de lui-même si ses frais attendent le
  /// voyageur, sinon la carte d'information est amenée à l'écran.
  final bool focusSupplement;

  /// Ouvert depuis une notification de modification (`?action=amendment` :
  /// `BID_AMENDMENT_REQUESTED`, `…_REMINDER`, `…_ACCEPTED`).
  final bool focusAmendment;

  const TravelerDetailBody({
    super.key,
    required this.bid,
    this.focusSupplement = false,
    this.focusAmendment = false,
  });

  /// La procédure « destinataire absent » (FLUTTER-E2) rend quelque chose :
  /// colis arrivé ou absence signalée par le voyageur (checklist, garde,
  /// colis non réclamé, chargement, erreur), sinon l'ancienne cellule de
  /// signalement quand elle s'affiche. Toujours en information sans titre :
  /// son contenu dépend d'un chargement asynchrone, et « À traiter » ne doit
  /// jamais montrer son titre sans rien dessous.
  static bool _showsNoShow(BidModel bid) =>
      DeliveryNoShowProcedureCard.shouldShow(bid, isSender: false) ||
      DeliveryNoShowCtaCell.shouldShow(bid);

  @override
  State<TravelerDetailBody> createState() => _TravelerDetailBodyState();
}

class _TravelerDetailBodyState extends State<TravelerDetailBody> {
  /// `true` uniquement lors du premier build : déclenche le stagger d'entrée.
  ///
  /// Passé à `false` après la durée totale du stagger (sans [setState] pour
  /// ne pas provoquer un rebuild parasite). Le prochain rebuild naturel du
  /// parent (polling → BidDetailLoaded) lira ce flag à `false` et affichera
  /// les cartes directement, sans rejouer l'animation.
  bool _playEntrance = true;

  /// Timer utilisé pour désactiver le stagger après la durée totale.
  /// Annulé dans [dispose] pour éviter les timers pendants en test.
  Timer? _entranceTimer;

  /// Encart du supplément, cible de [TravelerDetailBody.focusSupplement].
  final _supplementKey = GlobalKey();
  bool _supplementFocused = false;

  /// Mesure d'affichage des tuiles « À traiter », une fois par colis, tuile
  /// et statut pour cet écran.
  final _todoViews = TodoTileViewLog();

  /// Carte de la modification, cible de [TravelerDetailBody.focusAmendment].
  final _amendmentKey = GlobalKey();
  bool _amendmentFocused = false;

  @override
  void initState() {
    super.initState();
    // Durée totale = délai max (60 ms × 9, index plafonné) + durée fadeIn
    // (300 ms) + marge (50 ms).
    // Après ce délai, le flag est mis à false SANS setState : on ne veut pas
    // déclencher un rebuild ici, juste que le prochain rebuild (polling parent)
    // saute le stagger.
    const total = Duration(milliseconds: 60 * 9 + 300 + 50);
    _entranceTimer = Timer(total, () {
      _playEntrance = false;
    });
  }

  @override
  void dispose() {
    _entranceTimer?.cancel();
    super.dispose();
  }

  /// `?action=supplement`, une seule fois, au premier colis chargé (le corps
  /// ne reçoit jamais de squelette, l'écran affiche le sien) : frais à valider
  /// → le sheet de sa tuile s'ouvre (comme `?action=new-code`) ; autre état
  /// → la carte d'information est amenée à l'écran ; aucun supplément → rien.
  /// Consommé même sans supplément : une demande créée ensuite (menu ⋮)
  /// n'ouvre pas de sheet, attribué à tort au lien (`source: link`).
  void _maybeFocusSupplement() {
    final bid = widget.bid;
    if (!widget.focusSupplement || _supplementFocused) return;
    _supplementFocused = true;
    if (!SupplementTravelerCard.needsReply(bid)) {
      if (SupplementTravelerCard.shouldShow(bid)) _scrollTo(_supplementKey);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Une autre feuille déjà ouverte par-dessus la fiche : on n'empile pas.
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      unawaited(
        openTravelerTodoSheet(
          context,
          bid,
          TravelerTodoTile.supplement,
          source: TodoSource.link,
        ),
      );
    });
  }

  /// `?action=amendment` : la carte de la modification est amenée à l'écran,
  /// une seule fois, au premier colis chargé ; consommé même sans
  /// modification (une demande arrivée ensuite ne fait pas défiler).
  void _maybeFocusAmendment() {
    if (!widget.focusAmendment || _amendmentFocused) return;
    _amendmentFocused = true;
    if (AmendmentTravelerCard.shouldShow(widget.bid)) _scrollTo(_amendmentKey);
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

  /// Tuile de la section « À traiter » : pastille ambre, résumé de ce qui est
  /// attendu. Le tap ouvre le sheet avec le contexte de ce `State` (jamais
  /// celui de la tuile, qui disparaît dès que la demande est traitée).
  Widget _todoTileFor(TravelerTodoTile tile) {
    final bid = widget.bid;
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final iconName = switch (tile) {
      TravelerTodoTile.supplement => 'credit-card',
    };
    final badge = l.todoTileBadgeReplyNeeded;
    return DonyActionTile(
      key: Key('traveler-todo-${tile.name}'),
      iconName: iconName,
      label: travelerTodoTitle(l, tile),
      subtitle: travelerTodoSummary(l, bid, tile),
      color: cs.primary,
      badge: ToolStatusBadge(
        ready: false,
        tone: ToolStatusTone.news,
        label: badge,
        semanticsLabel: badge,
      ),
      onTap: () => unawaited(openTravelerTodoSheet(context, bid, tile)),
    );
  }

  /// Compte l'affichage des tuiles « À traiter » après l'image, une seule fois
  /// par colis, tuile et statut ([TodoTileViewLog]) ; plus la mesure de la
  /// carte reprise par la tuile ([travelerTodoViewed]), une fois par demande
  /// et statut de la demande.
  void _logTodoShown(List<TravelerTodoTile> tiles) {
    if (tiles.isEmpty) return;
    final bid = widget.bid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final tile in tiles) {
        _todoViews.logOnce(
          bidId: bid.id,
          tile: tile.name,
          shown: travelerTodoShown(tile, bid),
        );
        final viewed = travelerTodoViewed(tile, bid);
        if (viewed != null) {
          _todoViews.logOnce(
            bidId: bid.id,
            tile: '${tile.name}|card',
            shown: viewed,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Le verrou de la remise avant le départ vient du même
    // [DeliveryDepartureGate] que le bouton du footer : il tombe seul à l'heure
    // du départ et la carte disparaît avec lui. La porte enveloppe TOUJOURS le
    // corps (sans fenêtre elle ne verrouille jamais) : l'arbre reste stable
    // quand le statut passe de ACCEPTED à HANDED_OVER, les cartes ne sont pas
    // remontées.
    return DeliveryDepartureGate(
      window: TravelerStickyBar.hasDeliveryStep(widget.bid)
          ? DeliveryWindow.fromBid(widget.bid)
          : null,
      builder: (context, lockedHint) => _content(context, lockedHint),
    );
  }

  Widget _content(BuildContext context, String? lockedHint) {
    final h = DonyLayout.hPadding(context);
    final l = context.l10n;
    final bid = widget.bid;
    _maybeFocusSupplement();
    _maybeFocusAmendment();

    // Hero : sous le billet quand il informe (demande à décider, attente du
    // paiement, absence signalée), sous « À traiter » quand c'est une alerte
    // qui attend le voyageur. Aux étapes du transport il ne rend rien
    // (`isShown` faux) : aucune section, donc aucun espace vide.
    final hero = TravelerHeroCard.isShown(bid)
        ? TravelerHeroCard(bid: bid)
        : null;
    final heroAction = hero != null && TravelerHeroCard.hasAction(bid);

    // Supplément : tuile « À traiter » tant que ses frais attendent le
    // voyageur, sinon carte d'information sans titre (cible du défilement
    // `?action=supplement`).
    final supplement =
        SupplementTravelerCard.shouldShow(bid) &&
            !SupplementTravelerCard.needsReply(bid)
        ? SupplementTravelerCard(key: _supplementKey, bid: bid)
        : null;
    // Modification : sous « À traiter » tant qu'elle attend un geste du
    // voyageur, sinon simple information, sans titre. La clé de focus suit la
    // carte d'un côté comme de l'autre.
    final amendment = AmendmentTravelerCard.shouldShow(bid)
        ? AmendmentTravelerCard(key: _amendmentKey, bid: bid)
        : null;
    final amendmentReply =
        amendment != null && AmendmentTravelerCard.needsReply(bid);

    // Demandes qui attendent une réponse : une tuile chacune (frais du
    // supplément à valider), sous les cartes d'alerte.
    final todoTiles = travelerTodoTilesFor(bid);
    _logTodoShown(todoTiles);

    // « À traiter » ne réunit que ce qui attend une réponse ou un geste, et
    // seulement ce qui rend toujours un contenu (jamais un titre seul) : les
    // cartes d'alerte (hero à bouton, modification à bouton), puis la grille
    // des tuiles.
    final actions = <Widget>[
      if (heroAction) hero,
      if (amendmentReply) amendment,
      if (todoTiles.isNotEmpty)
        DonyActionTileGrid(
          key: const ValueKey('todo-tiles'),
          tiles: [for (final tile in todoTiles) _todoTileFor(tile)],
        ),
    ];

    // Informations sans titre : phrases d'aide sorties du footer (qui n'a
    // plus qu'un ou deux boutons), puis ce qui n'attend rien du voyageur.
    final infos = <(String, Widget)>[
      if (TravelerAwaitingPaymentCard.shouldShow(bid))
        ('info-awaiting-payment', const TravelerAwaitingPaymentCard()),
      if (TravelerScanBlockedCard.shouldShow(bid))
        ('info-scan-blocked', TravelerScanBlockedCard(bid: bid)),
      if (lockedHint != null)
        ('info-locked', TravelerHandoverLockedCard(lockedHint: lockedHint)),
      if (supplement != null) ('info-supplement', supplement),
      if (amendment != null && !amendmentReply) ('info-amendment', amendment),
      // Le voyageur n'a aucun bouton sur un report : l'expéditeur décide.
      if (TripRescheduleCard.shouldShow(bid))
        ('info-reschedule', TripRescheduleCard(bid: bid, isSender: false)),
      // Procédure « destinataire absent » (FLUTTER-E2) ; elle retombe sur
      // l'ancien signalement si le serveur ne la connaît pas encore.
      if (TravelerDetailBody._showsNoShow(bid))
        ('info-noshow', DeliveryNoShowProcedureCard(bid: bid, isSender: false)),
    ];

    // Chaque section porte une clé : l'apparition ou la disparition de
    // « À traiter » ou d'une information ne remonte ni l'expéditeur, ni le
    // gain, ni la grille. Hors du retrait de l'animation d'entrée (une fois,
    // voir plus bas), qui remonte les sections sans `GlobalKey`.
    final children = <(String, Widget)>[
      // index 0 — ColisBillet possède déjà son propre .animate().fadeIn().slideY()
      // en interne (colis_billet.dart). On ne lui applique PAS le stagger ici
      // pour éviter une double animation (fade × fade + slide × slide).
      ('billet', ColisBillet(bid: bid, isSender: false)),
      if (hero != null && !heroAction) ('hero', hero),
      if (actions.isNotEmpty)
        (
          'todo',
          BidDetailSection(title: l.bidDetailSectionTodo, children: actions),
        ),
      ...infos,
      // Profil de l'expéditeur à tous les statuts ; les boutons de contact
      // n'apparaissent qu'une fois la demande acceptée.
      ('expediteur', ExpediteurContactCard(bid: bid)),
      ('gain', TravelerGainCard(bid: bid)),
      // Lieux, colis et destinataire (avec son contact), détails : dans des
      // bottom sheets, plus dans le corps.
      ('transport', TravelerTransportSection(bid: bid)),
      if (bid.status == 'COMPLETED' && bid.travelerHasRated)
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
        // Délai plafonné à l'index 9 : la durée totale du timer ci-dessus
        // reste vraie quel que soit le nombre de cartes.
        final delay = (60 * (i > 9 ? 9 : i)).ms;
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
