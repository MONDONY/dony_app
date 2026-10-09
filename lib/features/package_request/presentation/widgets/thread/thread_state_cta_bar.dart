import 'dart:async';

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
import 'package:dony/features/package_request/presentation/widgets/thread/commission_countdown.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_state_banner.dart';
import 'package:dony/l10n/l10n.dart';
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
    if (!context.mounted) return;
    if (method == null) {
      // Retour sans détails validés : abandon, ou offre qui n'attend plus de
      // paiement (FLUTTER-F9). Le fil est rechargé pour refléter son état réel.
      bloc.add(NegotiationFetchRequested(thread.id));
      return;
    }
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
        final l = ctx.l10n;
        if (state is NegotiationNudgeSent) {
          DonySnackbar.show(
            ctx,
            message: l.negotiationNudgeSentMessage,
            type: DonySnackbarType.success,
          );
        } else if (state is NegotiationNudgeError) {
          DonySnackbar.show(
            ctx,
            message: state.error.code == 'nudge/rate-limited'
                ? l.negotiationNudgeRateLimitedMessage
                : l.negotiationNudgeGenericErrorMessage,
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
    final l = context.l10n;
    switch (thread.status) {
      case NegotiationThreadStatus.open:
        if (_lastFromMe) {
          return _AwaitingOtherWithEnd(
            threadId: thread.id,
            disabled: actionInProgress,
            banner: ThreadStateBanner(
              iconAsset: 'hourglass',
              tint: kWarning,
              message: l.negotiationOpenAwaitingReplyTitle,
              subtitle: l.negotiationOpenAwaitingReplySubtitle,
            ),
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
          return _AwaitingOtherWithEnd(
            threadId: thread.id,
            disabled: actionInProgress,
            banner: ThreadStateBanner(
              iconAsset: 'hourglass',
              tint: kWarning,
              message: l.negotiationAwaitingTripSenderTitle,
              subtitle: l.negotiationAwaitingTripSenderSubtitle,
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              label: l.negotiationLinkTripButton,
              onPressed: actionInProgress
                  ? null
                  : () => context.push(
                      '/negotiations/${thread.id}/link-trip',
                      extra: thread,
                    ),
            ),
            const SizedBox(height: 10),
            DonyButton(
              label: l.negotiationCreateDedicatedTripButton,
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
                label: l.negotiationCompleteAndPayButton(
                  PriceDisplay.money(
                    thread.grossPriceEur ??
                        PriceDisplay.grossFromNet(thread.currentPriceEur),
                    thread.currency,
                  ),
                ),
                onPressed: actionInProgress
                    ? null
                    : () => _completeDetailsThenPay(context, thread),
              )
            : _TravelerAwaitingPayment(
                banner: ThreadStateBanner(
                  iconAsset: 'banknote',
                  tint: kGreenPrimary,
                  message: l.negotiationAwaitingPaymentTravelerTitle,
                  subtitle: l.negotiationAwaitingPaymentTravelerSubtitle,
                ),
              );

      case NegotiationThreadStatus.awaitingDeposit:
        // Dépôt mobile money lancé par l'expéditeur : le fil attend la
        // confirmation de l'opérateur (délai court, `depositExpiresAt`). Le
        // voyageur n'a rien à faire ; l'expéditeur peut rouvrir l'écran
        // d'attente ou renoncer pour changer de moyen de paiement.
        if (!_isSender) {
          return _TravelerAwaitingPayment(
            banner: ThreadStateBanner(
              iconAsset: 'smartphone',
              tint: kGreenPrimary,
              message: l.negotiationAwaitingDepositTravelerTitle,
              subtitle: l.negotiationAwaitingDepositTravelerSubtitle,
            ),
          );
        }
        return _SenderDepositActions(
          thread: thread,
          actionInProgress: actionInProgress,
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
                message: l.negotiationAwaitingCommissionSenderTitle,
                subtitle: l.negotiationAwaitingCommissionSenderSubtitle,
              )
            : _TravelerCommissionActions(
                thread: thread,
                actionInProgress: actionInProgress,
              );

      case NegotiationThreadStatus.accepted:
        // En cash (et autres modes hors ligne), le paiement se fait en main
        // propre à la remise : ne pas afficher « payée ». Carte et mobile
        // money sont tous deux réglés en ligne avant l'acceptation.
        final bool paidOnline =
            thread.paymentMethod == null ||
            thread.paymentMethod == PaymentMethod.stripe ||
            thread.paymentMethod == PaymentMethod.mobileMoney;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThreadStateBanner(
              iconAsset: 'circle-check',
              tint: kSuccess,
              message: paidOnline
                  ? l.negotiationAcceptedPaidTitle
                  : l.negotiationAcceptedTitle,
              subtitle: paidOnline
                  ? l.negotiationAcceptedPaidSubtitle
                  : thread.paymentMethod == PaymentMethod.cash
                  ? l.negotiationAcceptedCashSubtitle
                  : l.negotiationAcceptedOtherSubtitle,
            ),
            // Entrée vers le détail de l'envoi (boutons no-show, suivi…) une fois
            // le bid matérialisé côté back.
            if (thread.materializedBidId != null) ...[
              const SizedBox(height: DonySpacing.sm),
              DonyButton(
                label: l.negotiationViewShipmentButton,
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
            l.negotiationEndedMessage,
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

/// Confirmation partagée de « Mettre fin à la négociation » : bouton visible
/// de l'état d'attente et entrée du menu ⋯ de l'écran du fil.
Future<void> confirmEndNegotiation(
  BuildContext context, {
  required String threadId,
}) async {
  final l = context.l10n;
  final bloc = context.read<NegotiationBloc>();
  final confirmed = await DonyDialog.show(
    context,
    title: l.negotiationEndDialogTitle,
    message: l.negotiationEndDialogMessage,
    confirmLabel: l.negotiationEndDialogConfirmButton,
    variant: DonyDialogVariant.destructive,
  );
  if (confirmed == true) {
    bloc.add(NegotiationCancelRequested(threadId: threadId));
  }
}

/// État « en attente de l'autre » (FLUTTER-EQ) : le bandeau, puis la sortie
/// « Mettre fin à la négociation » en bouton secondaire, jusque-là cachée
/// dans le menu ⋯. Statuts couverts : `open` après mon dernier message,
/// `awaitingTrip` côté expéditeur — avant tout paiement engagé.
class _AwaitingOtherWithEnd extends StatelessWidget {
  const _AwaitingOtherWithEnd({
    required this.threadId,
    required this.disabled,
    required this.banner,
  });

  final String threadId;
  final bool disabled;
  final Widget banner;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        banner,
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          key: const Key('thread-end-negotiation-btn'),
          label: context.l10n.negotiationEndMenuItem,
          variant: DonyButtonVariant.secondary,
          onPressed: disabled
              ? null
              : () => unawaited(
                  confirmEndNegotiation(context, threadId: threadId),
                ),
        ),
      ],
    );
  }
}

/// Voyageur dont l'offre est acceptée, paiement de l'expéditeur attendu ou en
/// cours (FLUTTER-F9) : « Retirer mon offre » reste visible mais désactivé,
/// avec la raison, plutôt que de disparaître sans explication. Le back refuse
/// de toute façon ce retrait (409 `offer-accepted-awaiting-payment`).
class _TravelerAwaitingPayment extends StatelessWidget {
  const _TravelerAwaitingPayment({required this.banner});

  final Widget banner;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        banner,
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          key: const Key('thread-withdraw-offer-locked-btn'),
          label: l.negotiationWithdrawOfferLockedButton,
          variant: DonyButtonVariant.secondary,
          onPressed: null,
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          l.negotiationWithdrawOfferLockedExplanation,
          key: const Key('thread-withdraw-offer-locked-explanation'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
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
      label: context.l10n.negotiationNudgeButton,
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

/// Sender · status AWAITING_DEPOSIT → bandeau « dépôt en cours » avec le
/// délai restant, reprise de l'écran d'attente, renoncement au dépôt.
///
/// Le délai est calculé au build (pas de timer) : le bandeau est informatif,
/// le vrai compte à rebours vit sur l'écran d'attente mobile money. À
/// l'échéance, le serveur ramène lui-même le fil en `AWAITING_PAYMENT`.
class _SenderDepositActions extends StatelessWidget {
  const _SenderDepositActions({
    required this.thread,
    required this.actionInProgress,
  });
  final NegotiationThread thread;
  final bool actionInProgress;

  /// Minutes restantes arrondies au supérieur (« Expire dans 1 min » jusqu'à
  /// la dernière seconde), 0 quand l'échéance est passée, `null` quand elle
  /// est inconnue : le bandeau ne doit alors ni annoncer un délai écoulé ni
  /// en inventer un. `depositExpiresAt` est en UTC : comparer à
  /// `DateTime.now().toUtc()`.
  int? get _remainingMinutes {
    final remaining = thread.depositExpiresAt?.difference(
      DateTime.now().toUtc(),
    );
    if (remaining == null) return null;
    if (remaining.isNegative) return 0;
    return remaining.inMinutes + 1;
  }

  String _subtitle(AppLocalizations l) => switch (_remainingMinutes) {
    null => l.negotiationDepositSubtitleDefault,
    0 => l.negotiationDepositSubtitleExpired,
    final minutes => l.negotiationDepositSubtitleExpiring(minutes),
  };

  Future<void> _resume(BuildContext context) async {
    final bloc = context.read<NegotiationBloc>();
    // L'écran d'attente rend `true` quand le paiement est séquestré : on
    // recharge le fil dans tous les cas, et on enchaîne sur l'écran de succès
    // uniquement si le dépôt a abouti (même parcours que la feuille de
    // récapitulatif).
    final paid = await context.push<bool>(
      '/negotiations/${thread.id}/mobile-money/awaiting',
    );
    if (!context.mounted) return;
    bloc.add(NegotiationFetchRequested(thread.id));
    if (paid == true) {
      unawaited(context.push('/negotiations/${thread.id}/paid'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThreadStateBanner(
          iconAsset: 'smartphone',
          tint: DonyColors.threadStatusViolet,
          message: l.negotiationDepositInProgressTitle,
          subtitle: _subtitle(l),
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          label: l.negotiationResumePaymentButton,
          onPressed: actionInProgress ? null : () => _resume(context),
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          label: l.negotiationChangePaymentMethodButton,
          variant: DonyButtonVariant.secondary,
          onPressed: actionInProgress
              ? null
              : () => context.read<NegotiationBloc>().add(
                  NegotiationCancelDepositRequested(thread.id),
                ),
        ),
      ],
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
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyButton(
          label: l.negotiationSenderAcceptButton(
            PriceDisplay.money(
              thread.grossPriceEur ??
                  PriceDisplay.grossFromNet(thread.currentPriceEur),
              thread.currency,
            ),
          ),
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
                  label: l.negotiationThreadKindCounter,
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
                label: l.negotiationDeclineButton,
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
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Accept button — visible only when backend says canAccept
        if (thread.canAccept) ...[
          DonyButton(
            label: l.negotiationTravelerAcceptButton(
              formatPriceIn(thread.currentPriceEur, thread.currency),
            ),
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
                label: l.negotiationDeclineButton,
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
                  label: l.negotiationThreadKindCounter,
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
    final l = context.l10n;
    final confirmed = await DonyDialog.show(
      context,
      title: l.negotiationDeclineParcelDialogTitle,
      message: l.negotiationDeclineParcelDialogMessage,
      confirmLabel: l.negotiationDeclineParcelConfirmButton,
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
    final l = context.l10n;
    // Estimation locale (mêmes bases que _NegotiationPriceBreakdown /
    // AcceptOfferBottomSheet) : le montant exact éventuellement ajusté par
    // un promo n'est recalculé côté serveur qu'au règlement lui-même.
    final commissionEur = PriceDisplay.feeFromNet(thread.currentPriceEur);
    final now = DateTime.now();
    final travelOver = isTravelDayOver(thread.travelerTravelDate, now);
    final deadline = effectiveCommissionDeadline(
      thread.commissionDeadline,
      thread.travelerTravelDate,
    );
    // Échéance déjà passée à l'affichage : le back refuserait le règlement
    // (409), le bouton ne doit pas le proposer (FLUTTER-44).
    final expired =
        travelOver || (deadline != null && !deadline.isAfter(now.toUtc()));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThreadStateBanner(
          iconAsset: 'clock',
          tint: cs.warning,
          message: l.negotiationCommissionTravelerBannerTitle,
          subtitle: l.negotiationCommissionTravelerBannerSubtitle(
            PriceDisplay.money(commissionEur, thread.currency),
          ),
        ),
        if (travelOver) ...[
          const SizedBox(height: DonySpacing.sm),
          Text(
            l.negotiationCommissionTravelDatePassed,
            key: const Key('commission-travel-date-passed'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else if (deadline != null) ...[
          const SizedBox(height: DonySpacing.sm),
          CommissionCountdown(deadline: deadline),
        ],
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          key: const Key('commission-pay-button'),
          label: l.negotiationPayCommissionButton,
          onPressed: actionInProgress || expired
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
              l.negotiationDeclineParcelButton,
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

/// Le voyage a-t-il eu lieu ? [travelDate] est un jour (minuit local) : il
/// est passé dès le lendemain.
@visibleForTesting
bool isTravelDayOver(DateTime travelDate, DateTime now) => !now.isBefore(
  DateTime(travelDate.year, travelDate.month, travelDate.day + 1),
);

/// Échéance de la commission affichée au voyageur : celle du back, mais
/// jamais au-delà du jour du voyage. Le minuteur annonçait encore du temps
/// alors que le voyage était passé (FLUTTER-44). `null` sans échéance back.
@visibleForTesting
DateTime? effectiveCommissionDeadline(
  DateTime? commissionDeadline,
  DateTime travelDate,
) {
  if (commissionDeadline == null) return null;
  final travelEnd = DateTime(
    travelDate.year,
    travelDate.month,
    travelDate.day + 1,
  ).toUtc();
  return commissionDeadline.isAfter(travelEnd) ? travelEnd : commissionDeadline;
}
