import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/pricing/dony_pricing.dart';
import 'package:dony/core/widgets/dony_icon.dart';
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
        // tant que le voyageur n'a pas réglé la commission Yadony : la
        // demande RESTE OUVERTE, un autre voyageur peut encore l'emporter.
        // Cas distinct de `accepted` (accords scellés) malgré la ressemblance
        // visuelle — ne jamais laisser l'expéditeur croire que c'est conclu.
        return _isSender
            ? ThreadStateBanner(
                iconAsset: 'clock',
                tint: cs.warning,
                message: 'En attente de la confirmation du voyageur',
                subtitle:
                    'Ta demande reste ouverte : tu peux continuer à recevoir '
                    "et accepter d'autres offres tant qu'il n'a pas réglé.",
              )
            : _TravelerCommissionActions(
                thread: thread,
                actionInProgress: actionInProgress,
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

/// Traveler · status AWAITING_COMMISSION → bandeau d'urgence (montant +
/// compte à rebours), bouton de règlement, action discrète de renoncement.
///
/// Rien n'est scellé tant que la commission n'est pas réglée : la demande
/// reste ouverte et un autre voyageur peut l'emporter avant lui — d'où
/// l'urgence rendue visible par le compte à rebours.
class _TravelerCommissionActions extends StatelessWidget {
  const _TravelerCommissionActions({
    required this.thread,
    required this.actionInProgress,
  });
  final NegotiationThread thread;
  final bool actionInProgress;

  Future<void> _confirmDecline(BuildContext context) async {
    final confirmed = await DonyDialog.show(
      context,
      title: 'Renoncer à ce colis ?',
      message:
          'La demande sera aussitôt disponible pour un autre voyageur. '
          'Cette action est définitive.',
      confirmLabel: 'Renoncer',
      variant: DonyDialogVariant.destructive,
    );
    if (confirmed == true && context.mounted) {
      context.read<NegotiationBloc>().add(
        NegotiationDeclineCommissionRequested(thread.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Estimation locale (mêmes bases que _NegotiationPriceBreakdown /
    // AcceptOfferBottomSheet) : le montant exact éventuellement ajusté par
    // un promo n'est recalculé côté serveur qu'au règlement lui-même.
    final commissionEur = PriceDisplay.feeFromNet(thread.currentPriceEur);
    final deadline = thread.commissionDeadline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThreadStateBanner(
          iconAsset: 'clock',
          tint: cs.warning,
          message: 'Confirme ta prise en charge',
          subtitle:
              "L'expéditeur a retenu ton offre. Règle la commission Yadony "
              '(${PriceDisplay.money(commissionEur, thread.currency)}) avant '
              "l'échéance pour emporter ce colis, sinon un autre voyageur "
              'peut te doubler.',
        ),
        if (deadline != null) ...[
          const SizedBox(height: DonySpacing.sm),
          _CommissionCountdown(deadline: deadline),
        ],
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          label: 'Régler la commission',
          onPressed: actionInProgress
              ? null
              : () => context.read<NegotiationBloc>().add(
                  NegotiationSettleCommissionRequested(thread.id),
                ),
        ),
        const SizedBox(height: DonySpacing.xs),
        Center(
          child: TextButton(
            onPressed: actionInProgress ? null : () => _confirmDecline(context),
            child: Text(
              'Renoncer à ce colis',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Compte à rebours jusqu'à [deadline] (UTC), isolé dans son propre widget
/// pour ne rafraîchir que ce texte chaque seconde, jamais le reste de l'écran.
/// S'arrête proprement à zéro (pas de durée négative affichée) et annule son
/// timer aussi bien à l'échéance qu'à la destruction du widget.
class _CommissionCountdown extends StatefulWidget {
  const _CommissionCountdown({required this.deadline});
  final DateTime deadline;

  @override
  State<_CommissionCountdown> createState() => _CommissionCountdownState();
}

class _CommissionCountdownState extends State<_CommissionCountdown> {
  Timer? _timer;

  /// Le restant vit dans un notifier, jamais dans un `setState` : la règle du
  /// projet l'interdit, et cela évite surtout de reconstruire toute la barre
  /// d'action à chaque tick. Seul le texte se redessine.
  late final ValueNotifier<Duration> _remaining = ValueNotifier(
    _computeRemaining(),
  );

  @override
  void initState() {
    super.initState();
    if (_remaining.value > Duration.zero) {
      _timer = Timer.periodic(_tickInterval(_remaining.value), (_) => _tick());
    }
  }

  /// La cadence suit la précision affichée : inutile de réveiller l'écran
  /// chaque seconde quand on affiche « 1h 45min ».
  Duration _tickInterval(Duration remaining) => remaining.inHours > 0
      ? const Duration(minutes: 1)
      : const Duration(seconds: 1);

  Duration _computeRemaining() {
    final diff = widget.deadline.difference(DateTime.now().toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _tick() {
    if (!mounted) return;
    final remaining = _computeRemaining();
    final wasHours = _remaining.value.inHours > 0;
    _remaining.value = remaining;
    if (remaining == Duration.zero) {
      _timer?.cancel();
      return;
    }
    // On vient de passer sous l'heure : repasser à la seconde.
    if (wasHours && remaining.inHours == 0) {
      _timer?.cancel();
      _timer = Timer.periodic(_tickInterval(remaining), (_) => _tick());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remaining.dispose();
    super.dispose();
  }

  static String _labelFor(Duration remaining) {
    if (remaining == Duration.zero) {
      return 'Délai écoulé';
    }
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);
    if (h > 0) {
      return 'Il te reste ${h}h ${m.toString().padLeft(2, '0')}min';
    }
    return 'Il te reste ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyIcon('timer', size: 14, color: cs.warning),
        const SizedBox(width: DonySpacing.xs),
        ValueListenableBuilder<Duration>(
          valueListenable: _remaining,
          builder: (context, remaining, _) => Text(
            _labelFor(remaining),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.warning,
              fontWeight: FontWeight.w700,
              // Chasse fixe : le texte ne doit pas sauter à chaque tick.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
