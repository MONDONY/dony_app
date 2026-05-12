import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart';
import 'package:dony/features/package_request/presentation/widgets/counter_offer_bottom_sheet.dart';
import 'package:dony/features/package_request/presentation/widgets/reject_bottom_sheet.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_state_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Barre de CTAs contextuels en bas du thread négociation.
///
/// Le contenu rendu dépend de la matrice (`status` × `isSender` × `lastFromMe`)
/// — couvre 5 statuts (OPEN/AWAITING_TRIP/AWAITING_PAYMENT/ACCEPTED/terminal)
/// + 2 rôles. Voir docs/spec-phases-1-4.md §3.1 pour la table de mapping.
///
/// Réutilise les bottom sheets existants (Accept / Counter / Reject) sans
/// modification de la logique BLoC.
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DonySpacing.lg, DonySpacing.sm, DonySpacing.lg, DonySpacing.base),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (thread.status) {
      case NegotiationThreadStatus.open:
        if (_lastFromMe) {
          return const ThreadStateBanner(
            icon: Icons.hourglass_top_rounded,
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
        return _isSender
            ? const ThreadStateBanner(
                icon: Icons.hourglass_top_rounded,
                tint: kWarning,
                message: 'Le voyageur prépare son trajet',
                subtitle: 'Tu seras notifié dès qu\'il l\'aura confirmé.',
              )
            : DonyButton(
                label: 'Lier un trajet à cette offre',
                onPressed: actionInProgress
                    ? null
                    : () => context.push(
                          '/negotiations/${thread.id}/link-trip',
                          extra: thread,
                        ),
              );

      case NegotiationThreadStatus.awaitingPayment:
        return _isSender
            ? DonyButton(
                label:
                    'Payer ${thread.currentPriceEur.toStringAsFixed(0)} €',
                onPressed: actionInProgress
                    ? null
                    : () => AcceptOfferBottomSheet.show(
                          context,
                          bloc: context.read<NegotiationBloc>(),
                          threadId: thread.id,
                          priceEur: thread.currentPriceEur,
                          isCheckout: true,
                        ),
              )
            : const ThreadStateBanner(
                icon: Icons.payments_outlined,
                tint: kGreenPrimary,
                message: 'En attente du paiement de l\'expéditeur',
                subtitle: 'Tu seras notifié dès qu\'il aura réglé.',
              );

      case NegotiationThreadStatus.accepted:
        return const ThreadStateBanner(
          icon: Icons.check_circle_rounded,
          tint: kSuccess,
          message: 'Demande acceptée et payée',
          subtitle: 'Tu peux passer aux étapes suivantes du suivi.',
        );

      case NegotiationThreadStatus.rejected:
      case NegotiationThreadStatus.autoRejected:
      case NegotiationThreadStatus.expired:
        return const SizedBox.shrink();
    }
  }
}

/// Sender · status OPEN · pas le dernier message → 3 actions :
/// Accept (prominent full-width) + Counter / Reject (row).
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
          label: 'Accepter ${thread.currentPriceEur.toStringAsFixed(0)} €',
          onPressed: actionInProgress
              ? null
              : () => AcceptOfferBottomSheet.show(
                    context,
                    bloc: context.read<NegotiationBloc>(),
                    threadId: thread.id,
                    priceEur: thread.currentPriceEur,
                  ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
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
                          roundsCount: thread.roundsCount,
                        ),
              ),
            ),
            const SizedBox(width: 10),
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

/// Traveler · status OPEN · pas le dernier message → 2 actions :
/// Reject / Counter (row).
class _TravelerOpenActions extends StatelessWidget {
  const _TravelerOpenActions({
    required this.thread,
    required this.actionInProgress,
  });
  final NegotiationThread thread;
  final bool actionInProgress;

  @override
  Widget build(BuildContext context) {
    return Row(
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
                      roundsCount: thread.roundsCount,
                    ),
          ),
        ),
      ],
    );
  }
}
