import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_card.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_sticky_bar.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Cartes d'information du corps de la fiche colis (vue voyageur) : les
/// phrases d'aide qui vivaient sous les boutons du footer.
///
/// Le footer ([TravelerStickyBar]) n'a qu'un bouton, ou deux sur une ligne, et
/// jamais de phrase. Ces cartes en reprennent le texte, aux mêmes conditions,
/// avec le composant d'information habituel ([DonyStatusBanner]).

/// Offre acceptée en mobile money, en attente du séquestre de l'expéditeur
/// (30 min, le bid repasse alors en ACCEPTED). Voir
/// [TravelerStickyBar.awaitingMobileMoneyPayment].
class TravelerAwaitingPaymentCard extends StatelessWidget {
  const TravelerAwaitingPaymentCard({super.key});

  static bool shouldShow(BidModel bid) =>
      TravelerStickyBar.awaitingMobileMoneyPayment(bid);

  @override
  Widget build(BuildContext context) => DonyStatusBanner(
    key: const Key('traveler-awaiting-payment-card'),
    type: DonyStatusBannerType.info,
    iconAsset: 'timer',
    message: context.l10n.bidDetailAwaitingSenderMobileMoneyPayment,
  );
}

/// Pourquoi le bouton de scan du footer est éteint : un supplément attend la
/// réponse de l'expéditeur (ou, en espèces, la validation de la commission du
/// voyageur, que « À traiter » lui demande), ou une modification attend celle
/// du voyageur.
class TravelerScanBlockedCard extends StatelessWidget {
  const TravelerScanBlockedCard({super.key, required this.bid});

  final BidModel bid;

  static bool shouldShow(BidModel bid) =>
      TravelerStickyBar.scanBlockedBySupplement(bid) ||
      TravelerStickyBar.scanBlockedByAmendment(bid);

  @override
  Widget build(BuildContext context) => DonyStatusBanner(
    key: const Key('traveler-scan-blocked-card'),
    type: DonyStatusBannerType.info,
    iconAsset: 'scan-line',
    message: _message(context),
  );

  /// Quand c'est au voyageur de valider sa commission, « À traiter » le lui
  /// demande : la carte ne doit pas dire que l'expéditeur doit répondre.
  String _message(BuildContext context) {
    final l = context.l10n;
    if (!TravelerStickyBar.scanBlockedBySupplement(bid)) {
      return l.amendmentScanBlocked;
    }
    return SupplementTravelerCard.needsReply(bid)
        ? l.bidDetailScanBlockedSupplementCommission
        : l.bidDetailScanBlockedSupplement;
  }
}

/// Pourquoi le bouton de remise du footer est éteint avant le départ du
/// trajet, et quel code demander au destinataire à la remise. [lockedHint] est
/// la phrase que `DeliveryDepartureGate` rend tant que le trajet n'est pas parti.
class TravelerHandoverLockedCard extends StatelessWidget {
  const TravelerHandoverLockedCard({super.key, required this.lockedHint});

  final String lockedHint;

  @override
  Widget build(BuildContext context) => DonyStatusBanner(
    key: const Key('traveler-handover-locked-card'),
    type: DonyStatusBannerType.info,
    iconAsset: 'clock',
    message: '$lockedHint\n${context.l10n.deliveryLockedHelp}',
  );
}
