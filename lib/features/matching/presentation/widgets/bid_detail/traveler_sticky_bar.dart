import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/announcement_bloc.dart';
import 'package:dony/features/matching/bloc/announcement_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/open_trip_validation.dart';
import 'package:dony/features/tracking/presentation/widgets/suivi_validate_content.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum _TravelerAction {
  decide,
  confirmPresence,
  scan,
  deliver,
  delete,
  awaitingMobileMoneyPayment,
}

/// Barre collante contextuelle voyageur — route vers le bon scanner/étape
/// selon le statut de l'offre.
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

  static _TravelerAction? _resolve(BidModel bid) {
    final now = DateTime.now();
    switch (bid.status) {
      // PENDING (cash / Mobile Money) ET PAYMENT_ESCROWED (carte, paiement
      // séquestré) : le voyageur doit pouvoir accepter/refuser depuis le détail,
      // comme la carte de liste (bid_list_screen._isPending couvre les deux).
      case 'PENDING':
      case 'PAYMENT_ESCROWED':
        return _TravelerAction.decide;
      // Le voyageur vient d'accepter une offre mobile money : l'expéditeur a
      // 30 min pour séquestrer via pawaPay. Rien à faire ici tant que le
      // paiement n'est pas séquestré (le bid repasse alors en ACCEPTED) —
      // simple ligne d'information, jamais un bouton scan/remise. Scopé au
      // mobile money : stripe/cash en AWAITING_PAYMENT restent hors
      // périmètre (barre vide, comportement historique).
      case 'AWAITING_PAYMENT':
        if (bid.paymentMethod == BidPaymentMethod.mobileMoney) {
          return _TravelerAction.awaitingMobileMoneyPayment;
        }
        return null;
      case 'REJECTED':
        return _TravelerAction.delete;
      case 'ACCEPTED':
        if (bid.voyageurConfirmed) {
          return _TravelerAction.scan;
        }
        final deadline = bid.handoverDeadline;
        // Date limite dépassée sans confirmation du voyageur → le hero prend le relais
        if (deadline != null && now.isAfter(deadline)) {
          return null;
        }
        return _TravelerAction.confirmPresence;
      // Colis récupéré (départ scanné) : la seule étape obligatoire restante
      // est la remise au destinataire. Le scan Transit est facultatif, proposé
      // en second tant qu'il n'a pas été fait (HANDED_OVER).
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
      case _TravelerAction.delete:
        return TravelerRejectedBar(bid: bid, isLoading: isLoading);
      case _TravelerAction.scan:
        return _ScanBar(bid: bid);
      case _TravelerAction.deliver:
        return _DeliverBar(
          bid: bid,
          offerOptionalTransit: bid.status == 'HANDED_OVER',
        );
      case _TravelerAction.awaitingMobileMoneyPayment:
        return const _AwaitingMobileMoneyPaymentBar();
    }
  }
}

// ── Awaiting mobile money payment bar ────────────────────────────────────────

/// Bid AWAITING_PAYMENT (mobile money) côté voyageur : ligne d'information
/// sans action, jamais de bouton scan/remise tant que l'expéditeur n'a pas
/// séquestré son paiement (30 min, le bid repasse alors en ACCEPTED).
class _AwaitingMobileMoneyPaymentBar extends StatelessWidget {
  const _AwaitingMobileMoneyPaymentBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final h = DonyLayout.hPadding(context);
    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DonyIcon('timer', size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.xs),
          Flexible(
            child: Text(
              context.l10n.bidDetailAwaitingSenderMobileMoneyPayment,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
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
      child: DonyButton(
        label: context.l10n.bidDetailScanParcelQr,
        iconAsset: 'scan-line',
        onPressed: () => openTripValidation(context, bid),
      ),
    );
  }
}

// ── Deliver bar ───────────────────────────────────────────────────────────────

class _DeliverBar extends StatelessWidget {
  const _DeliverBar({required this.bid, this.offerOptionalTransit = false});

  final BidModel bid;

  /// Colis récupéré, transit pas encore scanné : propose le scan Transit en
  /// action secondaire, jamais comme un passage obligé.
  final bool offerOptionalTransit;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            label: context.l10n.bidDetailConfirmHandover,
            iconAsset: 'badge-check',
            variant: DonyButtonVariant.success,
            onPressed: () => _deliver(context),
          ),
          if (offerOptionalTransit) ...[
            const SizedBox(height: DonySpacing.sm),
            DonyButton(
              key: const Key('traveler-optional-transit-btn'),
              label: context.l10n.bidDetailScanTransitOptional,
              iconAsset: 'arrow-left-right',
              variant: DonyButtonVariant.ghost,
              onPressed: () => context.push(
                '/tracking/scan/identify',
                extra: <String, dynamic>{
                  'etape': 'TRANSIT',
                  'focusNumber': false,
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
