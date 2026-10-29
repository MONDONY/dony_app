import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/cancellation/presentation/widgets/delivery_noshow_procedure_card.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/colis_destinataire_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/details_accordion.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/expediteur_contact_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_detail_body.dart'
    show RatingDoneBadge;
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_gain_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_hero_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_info_cards.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_sticky_bar.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/trip_reschedule_card.dart';
import 'package:dony/features/matching/presentation/widgets/billet/colis_billet.dart';
import 'package:dony/features/matching/presentation/widgets/recipient_contact/recipient_contact.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Corps de l'écran « Détail d'envoi » (vue voyageur).
///
/// Compose la nouvelle vue redesignée : billet de colis, hero contextuel,
/// carte expéditeur (si le bid est actif), carte colis & destinataire,
/// carte gain voyageur, actions rapides de suivi, accordéon de détails, et
/// badge d'évaluation si déjà notée.
///
/// Requiert les BLoCs ambiants suivants (fournis par l'écran parent) :
///   - [CancellationBloc] (via [TravelerHeroCard]),
///   - [ConversationOpenBloc] (via [ExpediteurContactCard]).
///
/// ## Animations
/// Le stagger d'entrée (fadeIn + slideY décalé de 60 ms × index) est joué
/// **une seule fois** grâce au flag [_TravelerDetailBodyState._playEntrance].
/// Les rebuilds suivants (polling toutes les 10 s du parent) rendent les
/// cartes sans re-déclencher l'animation — flag passé à `false` après la
/// durée totale du stagger, sans `setState` (pas de rebuild superflu).
class TravelerDetailBody extends StatefulWidget {
  final BidModel bid;

  const TravelerDetailBody({super.key, required this.bid});

  @override
  State<TravelerDetailBody> createState() => _TravelerDetailBodyState();
}

class _TravelerDetailBodyState extends State<TravelerDetailBody> {
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

  @override
  void initState() {
    super.initState();
    // Durée totale = délai max (60 ms × 9 pour 10 enfants au plus, index 0–9)
    // + durée fadeIn (300 ms) + marge (50 ms).
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

  @override
  Widget build(BuildContext context) {
    // Le verrou de la remise avant le départ vient du même
    // [DeliveryDepartureGate] que le bouton du footer : il tombe seul à l'heure
    // du départ et la carte disparaît avec lui.
    if (TravelerStickyBar.hasDeliveryStep(widget.bid)) {
      return DeliveryDepartureGate(
        window: DeliveryWindow.fromBid(widget.bid),
        builder: (context, lockedHint) => _content(context, lockedHint),
      );
    }
    return _content(context, null);
  }

  Widget _content(BuildContext context, String? lockedHint) {
    final h = DonyLayout.hPadding(context);
    final status = widget.bid.status;

    final children = <Widget>[
      // index 0 — ColisBillet possède déjà son propre .animate().fadeIn().slideY()
      // en interne (colis_billet.dart). On ne lui applique PAS le stagger ici
      // pour éviter une double animation (fade × fade + slide × slide).
      ColisBillet(bid: widget.bid, isSender: false),
      TravelerHeroCard(bid: widget.bid),
      // Phrases d'aide sorties du footer (qui n'a plus qu'un ou deux boutons).
      if (TravelerAwaitingPaymentCard.shouldShow(widget.bid))
        const TravelerAwaitingPaymentCard(),
      if (TravelerScanBlockedCard.shouldShow(widget.bid))
        TravelerScanBlockedCard(bid: widget.bid),
      if (lockedHint != null)
        TravelerHandoverLockedCard(lockedHint: lockedHint),
      // Supplément de prix : en attente, il bloque le scan de remise.
      if (SupplementTravelerCard.shouldShow(widget.bid))
        SupplementTravelerCard(bid: widget.bid),
      // Modification du colis : en attente, elle bloque le scan de remise.
      if (AmendmentTravelerCard.shouldShow(widget.bid))
        AmendmentTravelerCard(bid: widget.bid),
      if (TripRescheduleCard.shouldShow(widget.bid))
        TripRescheduleCard(bid: widget.bid, isSender: false),
      // Procédure « destinataire absent » (FLUTTER-E2) ; elle retombe sur
      // l'ancien signalement si le serveur ne la connaît pas encore.
      DeliveryNoShowProcedureCard(bid: widget.bid, isSender: false),
      // Profil de l'expéditeur à tous les statuts ; les boutons de contact
      // n'apparaissent qu'une fois la demande acceptée.
      ExpediteurContactCard(bid: widget.bid),
      ColisDestinataireCard(bid: widget.bid, isSender: false),
      // WhatsApp / SMS / appel au destinataire, message pré-rempli selon le
      // statut du colis (lot 3B). Seulement après le retrait du colis ; avant,
      // une ligne discrète annonce que le contact viendra (FLUTTER-JT).
      if (TravelerRecipientContactCard.shouldShow(widget.bid))
        TravelerRecipientContactCard(bid: widget.bid)
      else if (TravelerRecipientContactPendingNote.shouldShow(widget.bid))
        const TravelerRecipientContactPendingNote(),
      TravelerGainCard(bid: widget.bid),
      DetailsAccordion(bid: widget.bid, showTrackingLink: false),
      if (status == 'COMPLETED' && widget.bid.travelerHasRated)
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
        // Délai plafonné à l'index 9 : la durée totale du timer ci-dessus
        // reste vraie quel que soit le nombre de cartes.
        final delay = (60 * (i > 9 ? 9 : i)).ms;
        staggered.add(
          child
              .animate()
              .fadeIn(duration: 300.ms, delay: delay)
              .slideY(begin: 0.04, curve: Curves.easeOutCubic, delay: delay),
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
