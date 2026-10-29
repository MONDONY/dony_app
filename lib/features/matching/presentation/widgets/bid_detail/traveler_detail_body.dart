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
/// Ordre : billet de colis ; hero sans titre quand il ne porte pas de bouton
/// (demande à décider, attente du paiement, absence signalée : les étapes du
/// transport n'ont plus de carte d'information, le footer les porte) ;
/// « À traiter » (ce qui attend un geste du voyageur : le
/// hero à bouton, le supplément et la modification à bouton, seulement s'il y
/// a quelque chose) ; cartes d'information sans titre (attente du paiement,
/// scan bloqué, verrou avant le départ, supplément et modification qui
/// n'attendent rien de lui, trajet reporté, procédure « destinataire absent »
/// dans tous ses états) ; expéditeur ; gain ; grille de tuiles « Votre
/// transport » (Lieux, Colis et destinataire, Plus de détails), chacune
/// ouvrant un bottom sheet ([TravelerTransportSection]) ; badge d'évaluation
/// si déjà notée.
///
/// Une carte qui change de section ne perd pas son état : le supplément et la
/// modification portent une `GlobalKey` (cible du défilement `?action=`), qui
/// les déplace de « À traiter » à l'information (ou l'inverse) SANS les
/// remonter. Leur `State` est gardé, leurs cubits ne sont pas recréés et les
/// événements `*_viewed` ne repartent pas. Le hero, sans clé, est remonté
/// quand il gagne ou perd son bouton (choix assumé).
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

    // Hero : sous le billet quand il informe (demande à décider, attente du
    // paiement, absence signalée), sous « À traiter » quand c'est une alerte
    // qui attend le voyageur. Aux étapes du transport il ne rend rien
    // (`isShown` faux) : aucune section, donc aucun espace vide.
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

    // « À traiter » ne réunit que ce qui attend une réponse ou un geste, et
    // seulement des cartes qui rendent toujours un contenu (jamais un titre
    // seul) : le hero à bouton, le supplément et la modification à bouton.
    final actions = <Widget>[
      if (heroAction) hero,
      if (supplementReply) supplement,
      if (amendmentReply) amendment,
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
