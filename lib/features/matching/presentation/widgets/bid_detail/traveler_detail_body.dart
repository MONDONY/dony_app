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
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_info_cards.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_sticky_bar.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_transport_section.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/trip_reschedule_card.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Corps de l'écran « Détail d'envoi » (vue voyageur).
///
/// Ordre : billet de colis ; hero « prochaine étape » sans titre quand il ne
/// fait qu'informer ; « À traiter » (ce qui attend un geste du voyageur, et le
/// hero quand c'est une alerte, seulement s'il y a quelque chose) ; cartes
/// d'information sans titre (attente du paiement, scan bloqué, verrou avant le
/// départ, supplément et modification qui n'attendent rien de lui, trajet
/// reporté, garde du colis) ; expéditeur ; gain ; grille de tuiles « Votre
/// transport » (Lieux, Colis et destinataire, Plus de détails), chacune
/// ouvrant un bottom sheet ([TravelerTransportSection]) ; badge d'évaluation
/// si déjà notée.
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
  /// l'encart du supplément est amené à l'écran au premier affichage où il
  /// existe.
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

  /// Où va la procédure « destinataire absent » (FLUTTER-E2), qui retombe sur
  /// l'ancienne cellule de signalement quand elle ne s'applique pas.
  ///
  /// - « À traiter » : colis arrivé et pas encore signalé par le voyageur
  ///   (étapes puis « Signaler le destinataire absent »), ou cellule de
  ///   signalement visible (remis, en route ou arrivé, départ passé, aucun
  ///   signalement en cours) ;
  /// - information sans titre : signalement déjà fait par le voyageur (garde
  ///   du colis, colis non réclamé, ou rien) ; la placer sous « À traiter »
  ///   laisserait le titre seul quand la procédure n'a rien à montrer ;
  /// - absente sinon (elle ne rendrait rien).
  static _NoShowPlace _noShowPlace(BidModel bid) {
    if (DeliveryNoShowProcedureCard.shouldShow(bid, isSender: false)) {
      return bid.deliveryNoShowReportedByTraveler == true
          ? _NoShowPlace.info
          : _NoShowPlace.todo;
    }
    return DeliveryNoShowCtaCell.shouldShow(bid)
        ? _NoShowPlace.todo
        : _NoShowPlace.none;
  }

  @override
  State<TravelerDetailBody> createState() => _TravelerDetailBodyState();
}

enum _NoShowPlace { todo, info, none }

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

  /// Amène l'encart du supplément à l'écran une seule fois, dès qu'il existe
  /// (le colis arrive souvent après le premier affichage, lien profond).
  void _maybeFocusSupplement() {
    if (!widget.focusSupplement ||
        _supplementFocused ||
        !SupplementTravelerCard.shouldShow(widget.bid)) {
      return;
    }
    _supplementFocused = true;
    _scrollTo(_supplementKey);
  }

  /// Même chose pour la carte de la modification (`?action=amendment`).
  void _maybeFocusAmendment() {
    if (!widget.focusAmendment ||
        _amendmentFocused ||
        !AmendmentTravelerCard.shouldShow(widget.bid)) {
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

    // Hero : sous le billet quand il informe, sous « À traiter » quand c'est
    // une alerte qui attend le voyageur.
    final hero = TravelerHeroCard.isShown(bid)
        ? TravelerHeroCard(bid: bid)
        : null;
    final heroAction = hero != null && TravelerHeroCard.hasAction(bid);

    // Supplément et modification : sous « À traiter » tant qu'ils attendent
    // un geste du voyageur, sinon simples informations, sans titre. La clé de
    // focus suit la carte d'un côté comme de l'autre.
    final supplement = SupplementTravelerCard.shouldShow(bid)
        ? SupplementTravelerCard(key: _supplementKey, bid: bid)
        : null;
    final supplementReply =
        supplement != null && SupplementTravelerCard.needsReply(bid);
    final amendment = AmendmentTravelerCard.shouldShow(bid)
        ? AmendmentTravelerCard(key: _amendmentKey, bid: bid)
        : null;
    final amendmentReply =
        amendment != null && AmendmentTravelerCard.needsReply(bid);

    // Procédure « destinataire absent » (FLUTTER-E2) ; elle retombe sur
    // l'ancien signalement si le serveur ne la connaît pas encore.
    final noShowPlace = TravelerDetailBody._noShowPlace(bid);
    final noShow = DeliveryNoShowProcedureCard(bid: bid, isSender: false);

    // « À traiter » ne réunit que ce qui attend une réponse ou un geste.
    final actions = <Widget>[
      if (heroAction) hero,
      if (supplementReply) supplement,
      if (amendmentReply) amendment,
      if (noShowPlace == _NoShowPlace.todo) noShow,
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
      if (supplement != null && !supplementReply)
        ('info-supplement', supplement),
      if (amendment != null && !amendmentReply) ('info-amendment', amendment),
      // Le voyageur n'a aucun bouton sur un report : l'expéditeur décide.
      if (TripRescheduleCard.shouldShow(bid))
        ('info-reschedule', TripRescheduleCard(bid: bid, isSender: false)),
      if (noShowPlace == _NoShowPlace.info) ('info-noshow', noShow),
    ];

    // Chaque section porte une clé : l'apparition ou la disparition de
    // « À traiter » ou d'une information ne remonte ni l'expéditeur, ni le
    // gain, ni la grille.
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
