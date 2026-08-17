import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/matching/bloc/bid_bloc.dart';
import 'package:dony/features/matching/bloc/bid_event.dart';
import 'package:dony/features/matching/bloc/shipment_filter_cubit.dart';
import 'package:dony/features/matching/data/models/bid_model.dart';
import 'package:dony/features/matching/presentation/widgets/action_bars/bid_detail_action_bars.dart';
import 'package:dony/features/matching/presentation/widgets/bid_detail/qr_sheet.dart';
import 'package:dony/features/payments/data/models/payment_model.dart';
import 'package:dony/features/ratings/presentation/widgets/rating_bottom_sheet.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_timeline_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Height shared by [EscrowBadge], [DonyButton], and the loading placeholder —
/// keeps the bar at a fixed size to avoid layout shifts when the payment state
/// resolves.
const double _kBarItemHeight = 52.0;

/// Barre sticky bas d'écran portant l'action primaire du statut (vue expéditeur).
///
/// Remplacera [SenderActionBar] côté sender au branchement (task 7).
/// Le menu options ⋮ n'est PAS dans cette barre (déplacé en app bar, task 7).
class SenderStickyBar extends StatelessWidget {
  final BidModel bid;
  final bool isLoading;
  final PaymentModel? existingPayment;
  final bool paymentLoaded;

  const SenderStickyBar({
    super.key,
    required this.bid,
    required this.isLoading,
    this.existingPayment,
    this.paymentLoaded = false,
  });

  // ── Static helper ────────────────────────────────────────────────────────────

  /// Returns true if the bar should be shown for this [bid] state.
  ///
  /// The caller can hide the bar entirely when this returns false (e.g. when
  /// the hero already handles the PENDING_CONFIRMATION actions).
  ///
  /// **Contract — superset gate:**
  /// This method is intentionally based on [bid] alone and ignores
  /// [paymentLoaded]/[existingPayment]. The bar can render without a primary
  /// action button in two valid cases:
  ///   1. PENDING/ACCEPTED + stripe + paid → [EscrowBadge] only (no button).
  ///   2. PENDING/ACCEPTED + stripe + loading → placeholder skeleton (no button yet).
  ///
  /// Do NOT "synchronise" this gate with [_buildAction]: it is a *superset*
  /// of what [_buildAction] ultimately renders, and that is by design.
  static bool hasAction(BidModel bid) {
    if (bid.cancellationNoShowStatus == 'PENDING_CONFIRMATION') {
      return false;
    }

    final status = bid.status;

    if (status == 'AWAITING_PAYMENT') {
      return bid.paymentMethod == BidPaymentMethod.stripe;
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

    return kEnvoisPasses.contains(status);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = DonyLayout.hPadding(context);

    final action = _buildAction(context);

    // Determine whether to show the escrow badge
    final showBadge =
        (bid.status == 'PENDING' || bid.status == 'ACCEPTED') &&
        existingPayment != null;

    final content = showBadge
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EscrowBadge(payment: existingPayment!, bidStatus: bid.status),
              if (action != null) ...[
                const SizedBox(height: DonySpacing.sm),
                action,
              ],
            ],
          )
        : action;

    if (content == null) {
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
      child: content,
    );
  }

  // ── Action resolver ──────────────────────────────────────────────────────────

  Widget? _buildAction(BuildContext context) {
    // 1. PENDING_CONFIRMATION: no action (hero handles it)
    if (bid.cancellationNoShowStatus == 'PENDING_CONFIRMATION') {
      return null;
    }

    final status = bid.status;

    // 1.5 AWAITING_PAYMENT (stripe) : l'expéditeur a quitté la PaymentSheet
    //     avant d'autoriser l'escrow → reprendre le paiement. Le backend
    //     (createEscrow) recycle le PaymentIntent en attente et renvoie le
    //     clientSecret existant. On ne gate PAS sur existingPayment : un bid
    //     de checkout abandonné porte un PaymentEntity PENDING obsolète.
    if (status == 'AWAITING_PAYMENT' &&
        bid.paymentMethod == BidPaymentMethod.stripe) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            label: 'Payer mon envoi',
            iconAsset: 'lock',
            isLoading: isLoading,
            onPressed: isLoading
                ? null
                : () => context.push('/payments/pay', extra: bid),
          ),
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            label: 'Annuler la demande',
            variant: DonyButtonVariant.ghost,
            onPressed: isLoading
                ? null
                : () => _showDeleteDialog(
                    context,
                    title: 'Annuler la demande de transport ?',
                    body:
                        "Aucun paiement n'a été effectué. La demande sera retirée.",
                    confirmLabel: 'Oui, annuler',
                    dismissLabel: 'Retour',
                  ),
          ),
        ],
      );
    }

    // 2. Stripe payment loading placeholder: show a skeleton while the payment
    //    status is being fetched so there is no layout shift when it resolves.
    //    Only applies to stripe (cash has no online sender payment).
    if ((status == 'PENDING' || status == 'ACCEPTED') &&
        bid.paymentMethod == BidPaymentMethod.stripe &&
        !paymentLoaded) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        // _kBarItemHeight — évite tout layout shift au resolve
        height: _kBarItemHeight,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DonyRadius.lg),
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // 3. Needs payment: (PENDING || ACCEPTED) && stripe && paymentLoaded && not yet paid
    final needsPayment =
        (status == 'PENDING' || status == 'ACCEPTED') &&
        bid.paymentMethod == BidPaymentMethod.stripe &&
        paymentLoaded &&
        existingPayment == null;

    if (needsPayment) {
      return DonyButton(
        label: 'Payer mon envoi',
        iconAsset: 'lock',
        isLoading: isLoading,
        onPressed: isLoading
            ? null
            : () => context.push('/payments/pay', extra: bid),
      );
    }

    // 4. By status
    if (status == 'ACCEPTED') {
      return DonyButton(
        label: 'Afficher le QR de remise',
        iconAsset: 'qr-code',
        onPressed: () {
          // Haptic is handled by QrSheet.show internally — do not duplicate it.
          QrSheet.show(context, bidId: bid.id, status: bid.status);
        },
      );
    }

    // ARRIVED : le colis est arrivé mais pas encore retiré, le suivi reste la
    // bonne action primaire pour l'expéditeur.
    if (status == 'HANDED_OVER' ||
        status == 'IN_TRANSIT' ||
        status == 'ARRIVED') {
      final dep = bid.departureCity ?? '';
      final arr = bid.arrivalCity ?? '';
      final corridor = (dep.isNotEmpty && arr.isNotEmpty)
          ? '$dep → $arr'
          : 'Suivi du colis';
      return DonyButton(
        label: 'Suivi du colis',
        iconAsset: 'package',
        onPressed: () {
          HapticFeedback.lightImpact();
          showTrackingTimelineSheet(context, bidId: bid.id, corridor: corridor);
        },
      );
    }

    if (status == 'COMPLETED' || status == 'DELIVERED') {
      if (bid.senderHasRated) {
        return null;
      }
      return DonyButton(
        label: 'Noter le voyageur',
        iconAsset: 'star',
        onPressed: () {
          RatingBottomSheet.show(
            context,
            bidId: bid.id,
            travelerName: bid.travelerName ?? 'le voyageur',
          );
        },
      );
    }

    // Statuts ∈ kEnvoisPasses (hors COMPLETED/DELIVERED déjà traités ci-dessus)
    if (kEnvoisPasses.contains(status)) {
      return DonyButton(
        label: 'Supprimer cette demande',
        iconAsset: 'trash-2',
        variant: DonyButtonVariant.destructive,
        onPressed: () {
          HapticFeedback.mediumImpact();
          _showDeleteDialog(context);
        },
      );
    }

    return null;
  }

  // ── Delete dialog ────────────────────────────────────────────────────────────

  void _showDeleteDialog(
    BuildContext context, {
    String title = 'Supprimer cette demande ?',
    String body = 'Elle sera retirée définitivement de votre historique.',
    String confirmLabel = 'Supprimer',
    String dismissLabel = 'Annuler',
  }) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    // Capture the bloc before opening the dialog so the reference stays valid
    // even after the dialog route pushes a new layer above the BlocProvider.
    final bloc = context.read<BidBloc>();
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DonyRadius.sheet),
        ),
        title: Text(title, style: tt.headlineMedium),
        content: Text(
          body,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              dismissLabel,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: DonyColors.white,
              elevation: 0,
            ),
            child: Text(confirmLabel, style: tt.labelLarge),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed ?? false) {
        bloc.add(BidDeleteRequested(bid.id));
      }
    });
  }
}
