import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/data/models/payment_method.dart';
import 'package:dony/features/package_request/data/models/price_display.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart';
import 'package:dony/features/package_request/presentation/widgets/counter_offer_bottom_sheet.dart';
import 'package:dony/features/package_request/presentation/widgets/payment_recap_bottom_sheet.dart';
import 'package:dony/features/package_request/presentation/widgets/reject_bottom_sheet.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_state_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Barre de CTAs contextuels en bas du thread négociation.
class ThreadStateCtaBar extends StatelessWidget {
  const ThreadStateCtaBar({
    super.key,
    required this.thread,
    required this.viewerUserId,
    required this.actionInProgress,
  });

  final NegotiationThread thread;
  final String viewerUserId;
  final bool actionInProgress;

  bool get _isSender => thread.travelerId != viewerUserId;
  bool get _lastFromMe =>
      thread.messages.isNotEmpty &&
      thread.messages.last.fromUserId == viewerUserId;

  /// Sender flow at AWAITING_PAYMENT: complete the post-acceptance details
  /// (recipient, addresses, declared value, disclaimer) BEFORE paying.
  ///
  /// The backend `/checkout` rejects with `request/details-incomplete` if those
  /// are missing, and for Stripe it would authorise the card before the gate
  /// fires — so we always route through complete-details first, then open the
  /// payment recap once the details are saved.
  Future<void> _completeDetailsThenPay(
    BuildContext context,
    NegotiationThread thread,
  ) async {
    final bloc = context.read<NegotiationBloc>();
    // The complete-details screen returns the payment method the sender chose
    // among the accepted ones (null = cancelled / not completed).
    final method = await context.push<PaymentMethod>(
      '/package-requests/${thread.packageRequestId}/complete-details',
      extra: thread,
    );
    if (method == null || !context.mounted) return;
    await PaymentRecapBottomSheet.show(
      context,
      bloc: bloc,
      thread: thread,
      paymentMethod: method,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocListener<NegotiationBloc, NegotiationState>(
      listenWhen: (previous, current) =>
          current is NegotiationNudgeSent || current is NegotiationNudgeError,
      listener: (ctx, state) {
        if (state is NegotiationNudgeSent) {
          DonySnackbar.show(
            ctx,
            message: 'Relance envoyée',
            type: DonySnackbarType.success,
          );
        } else if (state is NegotiationNudgeError) {
          DonySnackbar.show(
            ctx,
            message: state.error.code == 'nudge/rate-limited'
                ? 'Déjà relancé récemment'
                : 'Impossible de relancer pour le moment, réessaie plus tard',
            type: DonySnackbarType.warning,
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceWarm,
          border: Border(top: BorderSide(color: cs.outline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.md,
              DonySpacing.lg,
              DonySpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildContent(context),
                if (thread.canNudge) ...[
                  const SizedBox(height: DonySpacing.sm),
                  _NudgeButton(threadId: thread.id, disabled: actionInProgress),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (thread.status) {
      case NegotiationThreadStatus.open:
        if (_lastFromMe) {
          return const ThreadStateBanner(
            iconAsset: 'hourglass',
            tint: kWarning,
            message: 'En attente de la réponse',
            subtitle: 'Tu seras notifié dès que la partie adverse répondra.',
          );
        }
        return _isSender
            ? _SenderOpenActions(
                thread: thread,
                actionInProgress: actionInProgress,
              )
            : _TravelerOpenActions(
                thread: thread,
                actionInProgress: actionInProgress,
              );

      case NegotiationThreadStatus.awaitingTrip:
        if (_isSender) {
          return const ThreadStateBanner(
            iconAsset: 'hourglass',
            tint: kWarning,
            message: 'Le voyageur prépare son trajet',
            subtitle: "Tu seras notifié dès qu'il l'aura confirmé.",
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              label: 'Lier un trajet à cette offre',
              onPressed: actionInProgress
                  ? null
                  : () => context.push(
                      '/negotiations/${thread.id}/link-trip',
                      extra: thread,
                    ),
            ),
            const SizedBox(height: 10),
            DonyButton(
              label: 'Créer un trajet dédié',
              variant: DonyButtonVariant.secondary,
              onPressed: actionInProgress
                  ? null
                  : () => context.push(
                      '/negotiations/${thread.id}/create-dedicated-trip',
                      extra: thread,
                    ),
            ),
          ],
        );

      case NegotiationThreadStatus.awaitingPayment:
        return _isSender
            ? DonyButton(
                label:
                    'Compléter & payer ${PriceDisplay.money(thread.grossPriceEur ?? PriceDisplay.grossFromNet(thread.currentPriceEur), thread.currency)}',
                onPressed: actionInProgress
                    ? null
                    : () => _completeDetailsThenPay(context, thread),
              )
            : const ThreadStateBanner(
                iconAsset: 'banknote',
                tint: kGreenPrimary,
                message: "En attente du paiement de l'expéditeur",
                subtitle: "Tu seras notifié dès qu'il aura réglé.",
              );

      case NegotiationThreadStatus.awaitingCommission:
        // Accord en espèces conclu par l'expéditeur, mais rien n'est scellé
        // tant que le voyageur n'a pas réglé la commission Yadony. Le
        // règlement effectif (bouton, sheet) arrive dans une tâche dédiée.
        return _isSender
            ? const ThreadStateBanner(
                iconAsset: 'hourglass',
                tint: kWarning,
                message: 'En attente du règlement de la commission',
                subtitle:
                    "L'accord sera scellé dès que le voyageur aura réglé "
                    'la commission Yadony.',
              )
            : const ThreadStateBanner(
                iconAsset: 'banknote',
                tint: kWarning,
                message: 'Règle la commission Yadony',
                subtitle:
                    'Il te reste à régler la commission pour valider cet '
                    'accord.',
              );

      case NegotiationThreadStatus.accepted:
        // En cash (et autres modes hors Stripe), le paiement se fait en main
        // propre à la remise : ne pas afficher « payée ».
        final bool paidOnline =
            thread.paymentMethod == null ||
            thread.paymentMethod == PaymentMethod.stripe;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThreadStateBanner(
              iconAsset: 'circle-check',
              tint: kSuccess,
              message: paidOnline
                  ? 'Demande acceptée et payée'
                  : 'Demande acceptée',
              subtitle: paidOnline
                  ? 'Tu peux passer aux étapes suivantes du suivi.'
                  : thread.paymentMethod == PaymentMethod.cash
                  ? 'Le paiement se fait en espèces à la remise du colis.'
                  : 'Le paiement se fait à la remise du colis.',
            ),
            // Entrée vers le détail de l'envoi (boutons no-show, suivi…) une fois
            // le bid matérialisé côté back.
            if (thread.materializedBidId != null) ...[
              const SizedBox(height: DonySpacing.sm),
              DonyButton(
                label: 'Voir mon envoi',
                variant: DonyButtonVariant.secondary,
                onPressed: () =>
                    context.push('/bids/${thread.materializedBidId}'),
              ),
            ],
          ],
        );

      case NegotiationThreadStatus.rejected:
      case NegotiationThreadStatus.autoRejected:
      case NegotiationThreadStatus.expired:
      case NegotiationThreadStatus.cancelled:
        return Center(
          child: Text(
            'Cette négociation est terminée',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        );
    }
  }
}

/// Bouton secondaire « Relancer » — visible uniquement quand le backend
/// autorise la relance (`thread.canNudge`), quel que soit le statut du thread.
class _NudgeButton extends StatelessWidget {
  const _NudgeButton({required this.threadId, required this.disabled});
  final String threadId;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return DonyButton(
      label: 'Relancer',
      variant: DonyButtonVariant.secondary,
      icon: Icons.notifications_active_rounded,
      onPressed: disabled
          ? null
          : () => context.read<NegotiationBloc>().add(
              NegotiationNudgeRequested(threadId),
            ),
    );
  }
}

/// Sender · status OPEN · pas le dernier message → Accepter + Contre-offre / Rejeter
class _SenderOpenActions extends StatelessWidget {
  const _SenderOpenActions({
    required this.thread,
    required this.actionInProgress,
  });
  final NegotiationThread thread;
  final bool actionInProgress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyButton(
          label:
              'Accepter : Tu paies ${PriceDisplay.money(thread.grossPriceEur ?? PriceDisplay.grossFromNet(thread.currentPriceEur), thread.currency)}',
          onPressed: actionInProgress
              ? null
              : () => AcceptOfferBottomSheet.show(
                  context,
                  bloc: context.read<NegotiationBloc>(),
                  threadId: thread.id,
                  priceEur: thread.currentPriceEur,
                  grossPriceEur: thread.grossPriceEur,
                  hasLinkedTrip: thread.travelerAnnouncementId != null,
                  currency: thread.currency,
                ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (thread.canCounter) ...[
              Expanded(
                child: DonyButton(
                  label: 'Contre-offre',
                  variant: DonyButtonVariant.secondary,
                  onPressed: actionInProgress
                      ? null
                      : () => CounterOfferBottomSheet.show(
                          context,
                          bloc: context.read<NegotiationBloc>(),
                          threadId: thread.id,
                          currentPriceEur: thread.currentPriceEur,
                          grossPriceEur: thread.grossPriceEur,
                          roundsCount: thread.roundsCount,
                          currency: thread.currency,
                        ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: DonyButton(
                label: 'Rejeter',
                variant: DonyButtonVariant.ghost,
                onPressed: actionInProgress
                    ? null
                    : () => RejectBottomSheet.show(
                        context,
                        bloc: context.read<NegotiationBloc>(),
                        threadId: thread.id,
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Traveler · status OPEN · pas le dernier message → Accepter (si canAccept) + Rejeter / Contre-offre
class _TravelerOpenActions extends StatelessWidget {
  const _TravelerOpenActions({
    required this.thread,
    required this.actionInProgress,
  });
  final NegotiationThread thread;
  final bool actionInProgress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Accept button — visible only when backend says canAccept
        if (thread.canAccept) ...[
          DonyButton(
            label:
                'Accepter : Tu reçois ${formatPriceIn(thread.currentPriceEur, thread.currency)}',
            onPressed: actionInProgress
                ? null
                : () => AcceptOfferBottomSheet.show(
                    context,
                    bloc: context.read<NegotiationBloc>(),
                    threadId: thread.id,
                    priceEur: thread.currentPriceEur,
                    grossPriceEur: thread.grossPriceEur,
                    isTraveler: true,
                    hasLinkedTrip: thread.travelerAnnouncementId != null,
                    currency: thread.currency,
                  ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: DonyButton(
                label: 'Rejeter',
                variant: DonyButtonVariant.ghost,
                onPressed: actionInProgress
                    ? null
                    : () => RejectBottomSheet.show(
                        context,
                        bloc: context.read<NegotiationBloc>(),
                        threadId: thread.id,
                      ),
              ),
            ),
            if (thread.canCounter) ...[
              const SizedBox(width: 10),
              Expanded(
                child: DonyButton(
                  label: 'Contre-offre',
                  onPressed: actionInProgress
                      ? null
                      : () => CounterOfferBottomSheet.show(
                          context,
                          bloc: context.read<NegotiationBloc>(),
                          threadId: thread.id,
                          currentPriceEur: thread.currentPriceEur,
                          grossPriceEur: thread.grossPriceEur,
                          isTraveler: true,
                          roundsCount: thread.roundsCount,
                          currency: thread.currency,
                        ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
