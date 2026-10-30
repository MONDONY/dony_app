import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/amendment_pay_button.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/cancel_before_payment_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/qr_sheet.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_tile_sheets.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/sender_tiles.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/supplement_pay_button.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/tracking_actions.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Barre sticky bas d'écran portant l'action du statut (vue expéditeur).
///
/// Règle du footer : UN bouton, ou DEUX boutons sur la même ligne (secondaire
/// à gauche = 1/3, principal à droite = 2/3), toujours des [DonyButton] de
/// 52 px. Jamais de badge, de phrase d'aide ni de bouton destructif plein :
/// l'état du paiement est dit par la carte Paiement du corps, et « Supprimer
/// cette demande » vit dans le menu ⋮ (`showSenderOptionsSheet`).
/// Sans bouton à montrer, la barre rend [SizedBox.shrink] (aucun padding).
class SenderStickyBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;
  final PaymentModel? existingPayment;
  final bool paymentLoaded;

  /// Appelé après le retour de l'écran d'attente mobile money
  /// (`/bids/{id}/mobile-money/awaiting`), quel que soit le résultat du pop
  /// (`true`, `false` ou `null`) : un pop sans paiement peut aussi signifier
  /// que le bid a expiré ou a été annulé entre-temps, recharger le détail
  /// reste toujours pertinent.
  final VoidCallback? onPaymentReturned;

  const SenderStickyBar({
    super.key,
    required this.bid,
    required this.isLoading,
    this.existingPayment,
    this.paymentLoaded = false,
    this.onPaymentReturned,
  });

  // ── Static helper ────────────────────────────────────────────────────────────

  /// Returns true if the bar should be shown for this [bid] state.
  ///
  /// The caller can hide the bar entirely when this returns false (e.g. when
  /// the hero already handles the PENDING_CONFIRMATION actions).
  ///
  /// **Contract — superset gate:**
  /// This method is intentionally based on [bid] alone and ignores
  /// [paymentLoaded]/[existingPayment]. The bar can render nothing (a
  /// [SizedBox.shrink], no padding) in one valid case: PENDING/ACCEPTED +
  /// stripe + paid — nothing left to do, the Paiement card says the state.
  /// While the payment is being fetched the bar shows « Payer mon envoi » as a
  /// disabled, loading [DonyButton] (same 52 px, no layout shift).
  ///
  /// Do NOT "synchronise" this gate with [_resolve]: it is a *superset*
  /// of what [_resolve] ultimately picks, and that is by design.
  static bool hasAction(BidModel bid) {
    if (bid.cancellationNoShowStatus == 'PENDING_CONFIRMATION') {
      return false;
    }

    // Supplément de prix à payer (carte, mobile money) ou à accepter
    // (espèces) : « Payer » ou « Accepter » prend la barre.
    if (SupplementPayButton.canPay(bid)) return true;

    // Modification de colis acceptée par le voyageur, à payer en mobile
    // money : « Payer » prend la barre.
    if (AmendmentPayButton.canPay(bid)) return true;

    final status = bid.status;

    if (status == 'AWAITING_PAYMENT') {
      // Stripe (reprise de paiement) et mobile money (le voyageur vient
      // d'accepter, fenêtre de 30 min pour séquestrer) ont toutes deux une
      // action. Cash n'en a pas : rien à payer en ligne.
      return bid.paymentMethod == BidPaymentMethod.stripe ||
          bid.paymentMethod == BidPaymentMethod.mobileMoney;
    }

    if (status == 'PENDING') {
      return bid.paymentMethod == BidPaymentMethod.stripe;
    }

    if (status == 'ACCEPTED' ||
        status == 'HANDED_OVER' ||
        status == 'IN_TRANSIT' ||
        status == 'ARRIVED') {
      return true;
    }

    if (status == 'COMPLETED' || status == 'DELIVERED') {
      return !bid.senderHasRated;
    }

    // Envois clos sans livraison (REJECTED, CANCELLED, NO_SHOW, EXPIRED,
    // PARCEL_REFUSED) : « Supprimer cette demande » est dans le menu ⋮, plus
    // de footer.
    return false;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);

    final action = _buildAction(context);
    if (action == null) {
      return const SizedBox.shrink();
    }

    return Container(
      color: cs.surface,
      padding: EdgeInsets.fromLTRB(
        h,
        DonySpacing.base,
        h,
        MediaQuery.of(context).padding.bottom + DonySpacing.base,
      ),
      child: action,
    );
  }

  // ── Action resolver ──────────────────────────────────────────────────────────

  /// Colis ACCEPTED dont le footer ne propose pas « Afficher le QR de
  /// remise » : paiement carte introuvable (« Payer mon envoi ») ou
  /// déclaration d'absence en attente (pas de footer). Le QR du colis reste
  /// alors au talon du billet (décision du propriétaire). Pendant la lecture
  /// du paiement, non : le footer le proposera dans le cas courant, le talon
  /// ne s'ouvre pas pour se refermer aussitôt. Un supplément ou une
  /// modification à payer ne le laisse pas non plus : le voyageur ne peut pas
  /// scanner tant qu'ils attendent.
  ///
  /// Lit le même résolveur que la barre ([_resolve]) : footer et talon ne
  /// peuvent pas diverger.
  static bool leavesQrToTalon(
    BidModel bid, {
    required bool paymentLoaded,
    PaymentModel? existingPayment,
  }) =>
      bid.status == 'ACCEPTED' &&
      switch (_resolve(
        bid,
        paymentLoaded: paymentLoaded,
        existingPayment: existingPayment,
      )) {
        _SenderFooterAction.none || _SenderFooterAction.pay => true,
        _ => false,
      };

  /// Action du footer pour ce colis, sans la construire.
  static _SenderFooterAction _resolve(
    BidModel bid, {
    required bool paymentLoaded,
    PaymentModel? existingPayment,
  }) {
    // 1. PENDING_CONFIRMATION: no action (hero handles it)
    if (bid.cancellationNoShowStatus == 'PENDING_CONFIRMATION') {
      return _SenderFooterAction.none;
    }

    final status = bid.status;

    // 1.2 Supplément de prix demandé à la remise, colis payé par carte, en
    //     mobile money ou en espèces (acceptation, complément remis en main
    //     propre) : la réponse passe avant le QR, que le voyageur ne peut
    //     pas scanner tant que le supplément attend (409
    //     `handover-supplement-pending`).
    //     « Refuser » se trouve dans l'encart du supplément.
    if (SupplementPayButton.canPay(bid)) {
      return _SenderFooterAction.supplementPay;
    }

    // 1.3 Modification de colis acceptée, à payer en mobile money : même
    //     priorité que le supplément (le voyageur attend le dépôt).
    if (AmendmentPayButton.canPay(bid)) {
      return _SenderFooterAction.amendmentPay;
    }

    // 1.4 AWAITING_PAYMENT (mobile money) : le voyageur vient d'accepter,
    //     l'expéditeur a 30 min pour séquestrer via pawaPay.
    if (status == 'AWAITING_PAYMENT' &&
        bid.paymentMethod == BidPaymentMethod.mobileMoney) {
      return _SenderFooterAction.mobileMoneyPay;
    }

    // 1.5 AWAITING_PAYMENT (stripe) : l'expéditeur a quitté la PaymentSheet
    //     avant d'autoriser l'escrow → reprendre le paiement. Le backend
    //     (createEscrow) recycle le PaymentIntent en attente et renvoie le
    //     clientSecret existant. On ne gate PAS sur existingPayment : un bid
    //     de checkout abandonné porte un PaymentEntity PENDING obsolète.
    if (status == 'AWAITING_PAYMENT' &&
        bid.paymentMethod == BidPaymentMethod.stripe) {
      return _SenderFooterAction.cardResume;
    }

    final cardBeforeHandover =
        (status == 'PENDING' || status == 'ACCEPTED') &&
        bid.paymentMethod == BidPaymentMethod.stripe;

    // 2. Paiement stripe en cours de lecture : le bouton réel « Payer mon
    //    envoi » s'affiche désactivé en chargement (même hauteur de 52 px, donc
    //    aucun saut de mise en page quand l'état se résout). Seulement stripe
    //    (le cash n'a pas de paiement expéditeur en ligne).
    if (cardBeforeHandover && !paymentLoaded) {
      return _SenderFooterAction.payLoading;
    }

    // 3. Needs payment: (PENDING || ACCEPTED) && stripe && paymentLoaded && not yet paid
    if (cardBeforeHandover && existingPayment == null) {
      return _SenderFooterAction.pay;
    }

    // 4. By status
    if (status == 'ACCEPTED') return _SenderFooterAction.showQr;

    // ARRIVED : le colis est arrivé mais pas encore retiré, le suivi reste la
    // bonne action primaire pour l'expéditeur.
    if (status == 'HANDED_OVER' ||
        status == 'IN_TRANSIT' ||
        status == 'ARRIVED') {
      return _SenderFooterAction.track;
    }

    if ((status == 'COMPLETED' || status == 'DELIVERED') &&
        !bid.senderHasRated) {
      return _SenderFooterAction.rate;
    }

    return _SenderFooterAction.none;
  }

  Widget? _buildAction(BuildContext context) {
    return switch (_resolve(
      bid,
      paymentLoaded: paymentLoaded,
      existingPayment: existingPayment,
    )) {
      _SenderFooterAction.none => null,
      _SenderFooterAction.supplementPay => SupplementPayButton(
        key: ValueKey('supplement-pay-${bid.supplement!.id}'),
        bid: bid,
      ),
      _SenderFooterAction.amendmentPay => AmendmentPayButton(
        key: ValueKey('amendment-pay-${AmendmentPayButton.payable(bid)!.id}'),
        bid: bid,
      ),
      // Le retour de l'écran d'attente (pop true/false/null) recharge
      // toujours le détail via [onPaymentReturned] — un pop sans paiement
      // peut aussi signifier que le bid a expiré ou a été annulé entre-temps.
      _SenderFooterAction.mobileMoneyPay => _cancelAndPayRow(
        context,
        pay: DonyButton(
          label: context.l10n.bidDetailPayByMobileMoney,
          isLoading: isLoading,
          onPressed: isLoading
              ? null
              : () async {
                  await context.push<bool>(
                    '/bids/${bid.id}/mobile-money/awaiting',
                  );
                  if (context.mounted) {
                    onPaymentReturned?.call();
                  }
                },
        ),
      ),
      _SenderFooterAction.cardResume => _cancelAndPayRow(
        context,
        pay: DonyButton(
          label: context.l10n.bidDetailPayMyShipment,
          isLoading: isLoading,
          onPressed: isLoading
              ? null
              : () => context.push('/payments/pay', extra: bid),
        ),
      ),
      _SenderFooterAction.payLoading => DonyButton(
        label: context.l10n.bidDetailPayMyShipment,
        iconAsset: 'lock',
        isLoading: true,
        onPressed: null,
      ),
      _SenderFooterAction.pay => DonyButton(
        label: context.l10n.bidDetailPayMyShipment,
        iconAsset: 'lock',
        isLoading: isLoading,
        onPressed: isLoading
            ? null
            : () => context.push('/payments/pay', extra: bid),
      ),
      _SenderFooterAction.showQr => DonyButton(
        label: context.l10n.bidDetailShowPickupQr,
        iconAsset: 'qr-code',
        onPressed: () {
          // Haptic is handled by QrSheet.show internally — do not duplicate it.
          QrSheet.show(context, bidId: bid.id, status: bid.status);
        },
      ),
      _SenderFooterAction.track => DonyButton(
        label: context.l10n.bidDetailTrackParcel,
        iconAsset: 'package',
        onPressed: () {
          HapticFeedback.lightImpact();
          // Même geste que la tuile « Suivi » de « Votre envoi » : la fenêtre
          // du suivi. Sans tuile (ni suivi du voyageur ni adresse), la frise.
          if (senderTilesFor(bid).contains(SenderTile.suivi)) {
            openSenderTileSheet(context, bid, SenderTile.suivi);
          } else {
            openSenderTrackingTimeline(context, bid);
          }
        },
      ),
      _SenderFooterAction.rate => DonyButton(
        label: context.l10n.bidDetailRateTraveler,
        iconAsset: 'star',
        onPressed: () {
          RatingBottomSheet.show(
            context,
            bidId: bid.id,
            travelerName:
                bid.travelerName ??
                context.l10n.bidDetailSenderTravelerFallback,
          );
        },
      ),
    };
  }

  // ── Annuler + Payer ──────────────────────────────────────────────────────────

  /// Ligne [Annuler 1/3 | principal 2/3] partagée par les blocs
  /// AWAITING_PAYMENT mobile money et stripe. « Annuler » ouvre la feuille de
  /// confirmation : vraie annulation (autorisation carte ou paiement en
  /// attente libéré, voyageur prévenu). Le BLoC retombe sur le masquage d'avant
  /// si le back ne connaît pas l'endpoint.
  ///
  /// Le bouton principal de la ligne n'a pas d'icône : sans elle, « Payer par
  /// mobile money » tient à taille nominale dans 2/3 de 360 dp. Les boutons
  /// seuls (E1 à E4, E8…) gardent la leur.
  Widget _cancelAndPayRow(BuildContext context, {required Widget pay}) {
    return Row(
      children: [
        Expanded(
          child: DonyButton(
            key: const Key('sender-cancel-before-payment'),
            label: context.l10n.commonCancel,
            variant: DonyButtonVariant.secondary,
            onPressed: isLoading
                ? null
                : () => _confirmCancelBeforePayment(context),
          ),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(flex: 2, child: pay),
      ],
    );
  }

  Future<void> _confirmCancelBeforePayment(BuildContext context) async {
    // Lu avant la feuille : la route modale est posée au-dessus du provider.
    final bloc = context.read<BidBloc>();
    final confirmed = await CancelBeforePaymentSheet.show(context, bid: bid);
    if (!confirmed) return;
    unawaited(HapticFeedback.mediumImpact());
    bloc.add(
      BidCancelBeforePaymentRequested(
        bid.id,
        paymentMethod: bid.paymentMethod == BidPaymentMethod.mobileMoney
            ? 'mobile_money'
            : 'stripe',
      ),
    );
  }
}

/// Action portée par le footer de l'expéditeur, résolue par
/// [SenderStickyBar._resolve] : le footer la construit, le talon du billet
/// lit seulement si le QR lui revient ([SenderStickyBar.leavesQrToTalon]).
enum _SenderFooterAction {
  none,
  supplementPay,
  amendmentPay,
  mobileMoneyPay,
  cardResume,
  payLoading,
  pay,
  showQr,
  track,
  rate,
}
