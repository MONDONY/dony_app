import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/open_trip_validation.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/traveler_hero_card.dart';
import 'package:dony/features/tracking/presentation/widgets/delivery_departure_gate.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_validate_content.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum _TravelerAction { decide, confirmPresence, scan, deliver }

/// Barre collante contextuelle voyageur — route vers le bon scanner/étape
/// selon le statut de l'offre.
///
/// Un seul bouton, ou deux sur la même ligne (secondaire à gauche = 1/3,
/// principal à droite = 2/3). Jamais de phrase d'aide : celles du scan bloqué,
/// du verrou avant le départ et de l'attente de paiement vivent dans des
/// cartes d'information du corps (`traveler_info_cards.dart`). « Supprimer cette
/// demande » et « Scanner le transit » sont des entrées du menu ⋮
/// (`traveler_options_sheet.dart`).
class TravelerStickyBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;

  const TravelerStickyBar({
    super.key,
    required this.bid,
    required this.isLoading,
  });

  // ── Static helper ────────────────────────────────────────────────────────────

  /// Returns true if this bar should be shown for the given [bid] status.
  static bool hasAction(BidModel bid) => _resolve(bid) != null;

  /// Le bouton de scan est affiché mais bloqué par un supplément en attente
  /// de l'expéditeur : le back refuserait le scan (409
  /// `handover-supplement-pending`).
  static bool scanBlockedBySupplement(BidModel bid) =>
      _resolve(bid) == _TravelerAction.scan &&
      (bid.supplement?.blocksHandover ?? false);

  /// Le bouton de scan est affiché mais bloqué par une modification en attente
  /// du voyageur (le supplément, s'il bloque aussi, est expliqué en premier).
  static bool scanBlockedByAmendment(BidModel bid) =>
      _resolve(bid) == _TravelerAction.scan &&
      !scanBlockedBySupplement(bid) &&
      bid.amendments.any((a) => a.blocksHandover);

  /// Le bouton de remise est affiché (colis récupéré, en route ou arrivé) :
  /// il dépend du verrou [DeliveryDepartureGate].
  static bool hasDeliveryStep(BidModel bid) =>
      _resolve(bid) == _TravelerAction.deliver;

  /// Offre acceptée en mobile money : l'expéditeur a 30 min pour séquestrer
  /// via pawaPay. Rien à faire côté voyageur, simple carte d'information.
  static bool awaitingMobileMoneyPayment(BidModel bid) =>
      bid.status == 'AWAITING_PAYMENT' &&
      bid.paymentMethod == BidPaymentMethod.mobileMoney;

  static _TravelerAction? _resolve(BidModel bid) {
    switch (bid.status) {
      // PENDING (cash / Mobile Money) ET PAYMENT_ESCROWED (carte, paiement
      // séquestré) : le voyageur doit pouvoir accepter/refuser depuis le détail,
      // comme la carte de liste (bid_list_screen._isPending couvre les deux).
      case 'PENDING':
      case 'PAYMENT_ESCROWED':
        return _TravelerAction.decide;
      // AWAITING_PAYMENT (mobile money, 30 min pour le séquestre) et REJECTED
      // n'ont plus de footer : la phrase d'attente est une carte du corps
      // ([awaitingMobileMoneyPayment]) et « Supprimer cette demande » une
      // entrée du menu ⋮.
      // ACCEPTED : « Confirmer ma présence » avant la date limite, puis
      // « Lire le QR du colis ». Le back n'exige pas la présence confirmée
      // pour le scan de départ, et ne passe un colis accepté en NO_SHOW
      // qu'une heure après la date limite, sans scan de départ ni
      // signalement (`BidRepository.findNoShowBids`) : passé la date limite,
      // la présence n'est plus à confirmer mais le colis peut encore être
      // remis. Le héros d'alerte (« Signaler l'absence ») reste dans
      // « À traiter ».
      //
      // Déclaration d'absence de l'expéditeur ouverte (en attente ou
      // contestée), présence non confirmée : pas de scan. Le back ne regarde
      // pas la déclaration au scan de départ et ne la clôt pas : sans réponse
      // sous 24 h, `NoShowContestationTimeoutJob` confirmerait l'absence, le
      // séquestre serait remboursé et l'expéditeur pénalisé alors que le
      // colis voyage. Même règle qu'avant la date limite dépassée : pas de
      // footer après elle, « Confirmer ma présence » avant.
      //
      // Risque connu, à traiter par une PR back : présence confirmée et
      // déclaration ouverte, le scan reste proposé (comportement antérieur,
      // gardé tel quel).
      case 'ACCEPTED':
        if (bid.voyageurConfirmed) {
          return _TravelerAction.scan;
        }
        if (!TravelerHeroCard.windowExpired(bid)) {
          return _TravelerAction.confirmPresence;
        }
        return TravelerHeroCard.senderNoShowOpen(bid)
            ? null
            : _TravelerAction.scan;
      // Colis récupéré (départ scanné) : la seule étape obligatoire restante
      // est la remise au destinataire. Le scan Transit est facultatif : entrée
      // du menu ⋮ tant qu'il n'a pas été fait (HANDED_OVER).
      // ARRIVED : trajet marqué arrivé, même action tant que la livraison
      // n'est pas confirmée.
      case 'HANDED_OVER':
      case 'IN_TRANSIT':
      case 'ARRIVED':
        return _TravelerAction.deliver;
      default:
        return null;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_resolve(bid)) {
      case null:
        return const SizedBox.shrink();
      case _TravelerAction.decide:
        return TravelerPendingBar(bid: bid, isLoading: isLoading);
      case _TravelerAction.confirmPresence:
        return ConfirmPresenceBar(bid: bid, isLoading: isLoading);
      case _TravelerAction.scan:
        return _ScanBar(bid: bid);
      case _TravelerAction.deliver:
        return _DeliverBar(bid: bid);
    }
  }
}

// ── Scan bar ──────────────────────────────────────────────────────────────────

class _ScanBar extends StatelessWidget {
  const _ScanBar({required this.bid});

  final BidModel bid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);
    final blocked =
        TravelerStickyBar.scanBlockedBySupplement(bid) ||
        TravelerStickyBar.scanBlockedByAmendment(bid);
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      // Mode Valider du Suivi, sur le trajet de ce colis (FLUTTER-9N) :
      // le QR lu y ouvre l'étape suivante, le retour ramène au colis.
      // Un supplément (ou une modification) en attente bloque la remise : le
      // back refuserait le scan (409 `handover-supplement-pending`). Le bouton
      // reste, éteint, avec un libellé court ; la phrase complète est une
      // carte du corps.
      child: DonyButton(
        key: const Key('traveler-scan-btn'),
        label: blocked
            ? context.l10n.bidDetailScanPending
            : context.l10n.bidDetailScanParcelQr,
        iconAsset: 'scan-line',
        onPressed: blocked ? null : () => openTripValidation(context, bid),
      ),
    );
  }
}

// ── Deliver bar ───────────────────────────────────────────────────────────────

class _DeliverBar extends StatelessWidget {
  const _DeliverBar({required this.bid});

  final BidModel bid;

  /// Remise au destinataire. Si le voyageur n'a pas encore déclaré son
  /// arrivée, on la lui propose d'abord : sans elle, l'expéditeur n'est pas
  /// prévenu et son suivi reste « En route » pendant qu'on lui demande le
  /// code (Sentry FLUTTER-5S). « Pas encore » continue sans rien déclarer.
  Future<void> _deliver(BuildContext context) async {
    if (bid.status == 'HANDED_OVER' || bid.status == 'IN_TRANSIT') {
      final l = context.l10n;
      final city = bid.arrivalCity?.trim() ?? '';
      final arrived = await DonyDialog.show(
        context,
        title: city.isEmpty
            ? l.travelerArrivalPromptTitleGeneric
            : l.travelerArrivalPromptTitle(city),
        message: l.travelerArrivalPromptMessage,
        confirmLabel: l.travelerArrivalPromptConfirm,
        cancelLabel: l.travelerArrivalPromptSkip,
        iconAsset: 'plane-landing',
      );
      if (!context.mounted || arrived == null) return;
      if (arrived) {
        context.read<AnnouncementBloc>().add(
          AnnouncementTripMarkArrivedRequested(
            announcementId: bid.announcementId,
          ),
        );
      }
    }
    if (!context.mounted) return;
    // Le colis est déjà ouvert : remise directe par photo puis code, comme
    // l'onglet Suivi. Passer par l'identification faisait retaper au
    // voyageur le numéro de suivi d'un colis qu'il avait sous les yeux
    // (Sentry FLUTTER-CX).
    await context.push<void>(
      '/tracking/scan/photo',
      extra: <String, dynamic>{
        'bidId': bid.id,
        'etape': 'ARRIVEE',
        'packageLabel': suiviParcelLabel(bid),
        'deliveryWindow': DeliveryWindow.fromBid(bid),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      // Redirige vers l'étape Arrivée du hub de scan (identify → confirm), qui
      // dispatche ConfirmDeliveryRequested et libère le paiement — au lieu de
      // l'écran de réception autonome (/tracking/confirm).
      //
      // Pas de remise avant le départ du trajet : le back la refuse (422
      // trip-not-departed, FLUTTER-CB). Le bouton, éteint, dit « Disponible au
      // départ » et s'active seul à l'heure du départ ; les deux phrases du
      // verrou sont une carte du corps (même [DeliveryDepartureGate]). Le scan
      // du transit (facultatif) est une entrée du menu ⋮.
      child: DeliveryDepartureGate(
        window: DeliveryWindow.fromBid(bid),
        builder: (context, lockedHint) => DonyButton(
          key: const Key('traveler-deliver-btn'),
          label: lockedHint == null
              ? context.l10n.bidDetailConfirmHandover
              : context.l10n.bidDetailHandoverLockedLabel,
          iconAsset: lockedHint == null ? 'badge-check' : 'clock',
          variant: DonyButtonVariant.success,
          onPressed: lockedHint == null ? () => _deliver(context) : null,
        ),
      ),
    );
  }
}
