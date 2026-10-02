import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/utils/format_weight.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/presentation/widgets/billet/copy_code_button.dart';
import 'package:dony/features/matching/presentation/widgets/detail_card.dart';
import 'package:dony/features/matching/presentation/widgets/shipment_card.dart';
import 'package:dony/features/messaging/bloc/open/conversation_open_event.dart';
import 'package:dony/features/messaging/presentation/widgets/recipient_conversation_launcher.dart';
import 'package:dony/features/profile/presentation/screens/profile_public_screen.dart';
import 'package:dony/features/receptions/bloc/reception_detail_cubit.dart';
import 'package:dony/features/receptions/data/models/reception.dart';
import 'package:dony/features/tracking/presentation/widgets/route_label.dart';
import 'package:dony/features/tracking/presentation/widgets/shipment_progress_bar.dart';
import 'package:dony/features/tracking/presentation/widgets/tracking_timeline_bottom_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Signature de l'ouverture du suivi, injectable pour les tests.
typedef ReceptionTimelineOpener =
    Future<void> Function(BuildContext context, Reception reception);

Future<void> _openTimeline(BuildContext context, Reception reception) =>
    showTrackingTimelineSheet(
      context,
      bidId: reception.bidId,
      departureCity: reception.departureCity,
      arrivalCity: reception.arrivalCity,
      trackingNumber: reception.trackingNumber,
      arrivalInstructions: reception.arrivalInstructions,
    );

/// Un colis que l'utilisateur va recevoir (lot 2 destinataire).
///
/// - Lien `PENDING` : l'expéditeur a saisi son numéro. Il confirme que le
///   colis est pour lui, ou le refuse.
/// - Lien `CONFIRMED` : étape du colis, détails, et surtout le code de
///   retrait, sans que l'expéditeur ait à le lui transmettre.
class ReceptionDetailScreen extends StatelessWidget {
  const ReceptionDetailScreen({
    super.key,
    required this.bidId,
    this.openTimeline,
  });

  final String bidId;

  /// Injecté en test ; sinon la feuille du suivi.
  final ReceptionTimelineOpener? openTimeline;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ReceptionDetailCubit>()..load(bidId),
      child: _ReceptionDetailView(openTimeline: openTimeline ?? _openTimeline),
    );
  }
}

class _ReceptionDetailView extends StatelessWidget {
  const _ReceptionDetailView({required this.openTimeline});

  final ReceptionTimelineOpener openTimeline;

  void _onAction(BuildContext context, ReceptionDetailLoaded state) {
    final l = context.l10n;
    switch (state.action) {
      case ReceptionAction.confirmed:
        DonySnackbar.show(
          context,
          message: l.receptionConfirmedSnackbar,
          type: DonySnackbarType.success,
        );
      case ReceptionAction.declined:
        // Message posé avant de quitter l'écran : le ScaffoldMessenger de
        // l'app le garde affiché sur l'onglet Suivi.
        DonySnackbar.show(context, message: l.receptionDeclinedSnackbar);
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/tracking');
        }
      case ReceptionAction.failed:
        ErrorPresenter.show(context, state.actionError);
      case ReceptionAction.idle ||
          ReceptionAction.confirming ||
          ReceptionAction.declining:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return BlocConsumer<ReceptionDetailCubit, ReceptionDetailState>(
      listenWhen: (previous, current) =>
          current is ReceptionDetailLoaded &&
          (previous is! ReceptionDetailLoaded ||
              previous.action != current.action),
      listener: (context, state) =>
          _onAction(context, state as ReceptionDetailLoaded),
      builder: (context, state) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          actions: const [DonyFeedbackButton()],
          backgroundColor: cs.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          leading: const DonyAppBarBackButton(),
          title: Text(l.receptionDetailTitle, style: tt.headlineLarge),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: cs.outline, height: 1),
          ),
        ),
        body: switch (state) {
          ReceptionDetailLoading() => const DonyDetailSkeleton(),
          ReceptionDetailError(notFound: true) => DonyEmptyState(
            key: const Key('reception-not-found'),
            mascotte: DonyMascotteType.aucunResultat,
            iconAsset: 'package',
            title: l.receptionNotFoundTitle,
            description: l.receptionNotFoundDescription,
            actionLabel: l.receptionNotFoundAction,
            onAction: () => context.go('/tracking'),
          ),
          ReceptionDetailError() => DonyEmptyState(
            key: const Key('reception-error'),
            mascotte: DonyMascotteType.erreurLegere,
            type: DonyEmptyStateType.error,
            iconAsset: 'wifi-off',
            title: l.receptionErrorTitle,
            description: l.receptionErrorDescription,
            actionLabel: l.commonRetry,
            onAction: () => context.read<ReceptionDetailCubit>().retry(),
          ),
          ReceptionDetailLoaded(:final reception) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.lg,
              DonySpacing.xl,
              DonySpacing.lg,
              DonySpacing.huge,
            ),
            child:
                (reception.isConfirmed
                        ? _ConfirmedContent(reception: reception)
                        : _PendingContent(reception: reception))
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: 0.04, curve: Curves.easeOutCubic),
          ),
        },
        bottomNavigationBar: state is ReceptionDetailLoaded
            ? _BottomBar(state: state, openTimeline: openTimeline)
            : null,
      ),
    );
  }
}

String? _formatDate(AppLocalizations l, DateTime? date) =>
    date == null ? null : DateFormat.yMMMMd(l.localeName).format(date);

// ─────────────────────────────────────────────────────────────
// Lien à confirmer
// ─────────────────────────────────────────────────────────────

class _PendingContent extends StatelessWidget {
  const _PendingContent({required this.reception});

  final Reception reception;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sender = reception.senderFirstName;
    final from = reception.departureCity;
    final to = reception.arrivalCity;
    final departure = _formatDate(l, reception.departureDate);
    final recipient = reception.recipientName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: DonySpacing.icon,
                    height: DonySpacing.icon,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(DonyRadius.md),
                    ),
                    child: const DonyEmoji.parcel(size: DonySpacing.iconSm),
                  ),
                  const SizedBox(width: DonySpacing.md),
                  Expanded(
                    child: Text(
                      sender != null
                          ? l.receptionPendingHeadline(sender)
                          : l.receptionPendingHeadlineAnonymous,
                      style: tt.headlineMedium?.copyWith(color: cs.onSurface),
                    ),
                  ),
                ],
              ),
              if (from != null && to != null) ...[
                const SizedBox(height: DonySpacing.md),
                RouteLabel(
                  from: from,
                  to: to,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
              if (departure != null) ...[
                const SizedBox(height: DonySpacing.xs),
                Text(
                  l.receptionDepartureOn(departure),
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
              if (recipient != null) ...[
                const SizedBox(height: DonySpacing.xs),
                Text(
                  l.receptionRecipientName(recipient),
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        if (reception.senderId case final senderId?) ...[
          const SizedBox(height: DonySpacing.base),
          _SenderCard(
            senderId: senderId,
            name: sender,
            avatarUrl: reception.senderAvatarUrl,
          ),
        ],
        const SizedBox(height: DonySpacing.xl),
        Text(
          l.receptionPendingQuestion,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          l.receptionPendingExplanation,
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Lien confirmé
// ─────────────────────────────────────────────────────────────

class _ConfirmedContent extends StatelessWidget {
  const _ConfirmedContent({required this.reception});

  final Reception reception;

  String _stepHeadline(AppLocalizations l) {
    final city = reception.arrivalCity;
    if (reception.bidStatus == 'ARRIVED' && city != null) {
      return l.receptionStepArrivedIn(city);
    }
    return l.receptionStepHeadline(reception.bidStatus);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final from = reception.departureCity;
    final to = reception.arrivalCity;
    final code = reception.confirmationCode;
    final instructions = reception.arrivalInstructions;

    final details = <Widget>[
      // Avec un id, la ligne voyageur devient sa carte (photo + profil).
      if (reception.travelerId == null)
        if (reception.travelerFirstName case final traveler?)
          DonyInfoRow(label: l.receptionTravelerLabel, value: traveler),
      if (_formatDate(l, reception.departureDate) case final date?)
        DonyInfoRow(label: l.receptionDepartureLabel, value: date),
      if (_formatDate(l, reception.arrivalDate) case final date?)
        DonyInfoRow(label: l.receptionArrivalLabel, value: date),
      if (reception.trackingNumber case final number?)
        DonyInfoRow(label: l.receptionTrackingNumberLabel, value: number),
      if (reception.weightKg case final kg?)
        DonyInfoRow(
          label: l.receptionWeightLabel,
          value: formatWeightKg(l, kg),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('reception-step'),
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _stepHeadline(l),
                style: tt.headlineMedium?.copyWith(color: cs.onSurface),
              ),
              if (from != null && to != null) ...[
                const SizedBox(height: DonySpacing.xs),
                RouteLabel(
                  from: from,
                  to: to,
                  style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: DonySpacing.md),
              ShipmentProgressBar(
                step: shipmentStepFor(reception.bidStatus) ?? 1,
              ),
              const SizedBox(height: DonySpacing.md),
              _ReceptionSteps(reception: reception),
            ],
          ),
        ),
        if (reception.senderId case final senderId?) ...[
          const SizedBox(height: DonySpacing.base),
          _SenderCard(
            senderId: senderId,
            name: reception.senderFirstName,
            avatarUrl: reception.senderAvatarUrl,
          ),
        ],
        if (reception.travelerId case final travelerId?) ...[
          const SizedBox(height: DonySpacing.base),
          _TravelerCard(
            travelerId: travelerId,
            name: reception.travelerFirstName,
            avatarUrl: reception.travelerAvatarUrl,
          ),
        ],
        const SizedBox(height: DonySpacing.base),
        if (code != null)
          _PickupCodeCard(code: code)
        else if (reception.bidStatus == 'ACCEPTED')
          Container(
            key: const Key('reception-code-pending'),
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(DonyRadius.card),
            ),
            child: Text(
              l.receptionCodePending,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
            ),
          ),
        if (details.isNotEmpty) ...[
          const SizedBox(height: DonySpacing.base),
          DetailCard(
            title: l.receptionDetailsTitle,
            child: Column(children: details),
          ),
        ],
        if (instructions != null) ...[
          const SizedBox(height: DonySpacing.base),
          DetailCard(
            title: l.receptionInstructionsTitle,
            child: Text(
              instructions,
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
            ),
          ),
        ],
      ],
    );
  }
}

/// Les quatre étapes du colis, avec leur libellé : la barre seule ne disait
/// pas ce qui était fait (Sentry FLUTTER-6E, « le colis a été donné mais
/// l'étape n'est pas complète »).
class _ReceptionSteps extends StatelessWidget {
  const _ReceptionSteps({required this.reception});

  final Reception reception;

  /// Étapes faites selon le statut du colis.
  int get _doneCount => switch (reception.bidStatus) {
    'HANDED_OVER' || 'IN_TRANSIT' => 1,
    'ARRIVED' => 3,
    'COMPLETED' => 4,
    _ => 0,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [
      l.receptionTimelineHandedOver,
      l.receptionTimelineInTransit,
      l.receptionTimelineArrived,
      l.receptionTimelineDelivered,
    ];
    final done = _doneCount;
    return Column(
      key: const Key('reception-steps'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < labels.length; i++)
          _StepRow(
            key: Key('reception-step-$i'),
            label: labels[i],
            state: i < done
                ? _StepState.done
                : i == done
                ? _StepState.current
                : _StepState.todo,
          ),
      ],
    );
  }
}

enum _StepState { done, current, todo }

class _StepRow extends StatelessWidget {
  const _StepRow({super.key, required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final (Widget icon, Color color, String status) = switch (state) {
      _StepState.done => (
        DonyIcon('circle-check', size: 18, color: cs.primary),
        cs.onSurface,
        l.receptionStepDoneSemantics,
      ),
      _StepState.current => (
        DonyIcon('circle-dot', size: 18, color: cs.secondary),
        cs.onSurface,
        l.receptionStepCurrentSemantics,
      ),
      _StepState.todo => (
        DonyIcon('circle', size: 18, color: cs.outline),
        cs.onSurfaceVariant,
        l.receptionStepTodoSemantics,
      ),
    };
    return Semantics(
      label: '$label, $status',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.xxs),
        child: Row(
          children: [
            icon,
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Text(
                label,
                style: tt.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: state == _StepState.current
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le voyageur, photo comprise : un tap ouvre son profil public (Sentry
/// FLUTTER-6F, 6G, 6H).
class _TravelerCard extends StatelessWidget {
  const _TravelerCard({
    required this.travelerId,
    required this.name,
    required this.avatarUrl,
  });

  final String travelerId;
  final String? name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final display = name ?? l.receptionTravelerLabel;
    return _ProfileCard(
      cardKey: const Key('reception-traveler-card'),
      userId: travelerId,
      role: l.receptionTravelerLabel,
      display: display,
      avatarUrl: avatarUrl,
      semanticsLabel: l.receptionViewTravelerProfile(display),
    );
  }
}

/// L'expéditeur, photo comprise : le titre « {prénom} vous envoie un colis »
/// ne menait nulle part, un tap sur cette carte ouvre son profil public
/// (Sentry FLUTTER-7P).
class _SenderCard extends StatelessWidget {
  const _SenderCard({
    required this.senderId,
    required this.name,
    required this.avatarUrl,
  });

  final String senderId;
  final String? name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final display = name ?? l.receptionSenderLabel;
    return _ProfileCard(
      cardKey: const Key('reception-sender-card'),
      userId: senderId,
      role: l.receptionSenderLabel,
      display: display,
      avatarUrl: avatarUrl,
      semanticsLabel: l.receptionViewSenderProfile(display),
    );
  }
}

/// Carte d'une personne liée au colis (rôle, photo, prénom) qui ouvre son
/// profil public.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.cardKey,
    required this.userId,
    required this.role,
    required this.display,
    required this.avatarUrl,
    required this.semanticsLabel,
  });

  final Key cardKey;
  final String userId;
  final String role;
  final String display;
  final String? avatarUrl;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: DonyPressable(
        key: cardKey,
        onTap: () => context.push(
          '/profile/public',
          extra: ProfilePublicArgs(userId: userId),
        ),
        child: Container(
          padding: const EdgeInsets.all(DonySpacing.base),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(DonyRadius.card),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              DonyAvatar(name: display, imageUrl: avatarUrl),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      display,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l.receptionSeeTravelerProfile,
                      style: tt.bodySmall?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
              ),
              DonyIcon('chevron-right', size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le code de retrait en grand : le destinataire le dicte au voyageur à la
/// remise. Chiffres à chasse fixe, pour qu'aucun ne se confonde.
class _PickupCodeCard extends StatelessWidget {
  const _PickupCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      key: const Key('reception-code'),
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.receptionCodeTitle,
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          Semantics(
            label: l.receptionCodeSemantics(code.split('').join(' ')),
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: tt.displaySmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          CopyCodeButton(
            code: code,
            label: l.ticketCopyCodeButton,
            copiedLabel: l.ticketCodeCopiedSnackbar,
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            l.receptionCodeExplanation,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Barre fixe
// ─────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.state, required this.openTimeline});

  final ReceptionDetailLoaded state;
  final ReceptionTimelineOpener openTimeline;

  Future<void> _decline(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<ReceptionDetailCubit>();
    final confirmed = await DonyDialog.show(
      context,
      title: l.receptionDeclineDialogTitle,
      message: l.receptionDeclineDialogMessage,
      confirmLabel: l.receptionDeclineButton,
      iconAsset: 'circle-help',
    );
    if (confirmed ?? false) await cubit.decline();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final reception = state.reception;
    // Après le refus, l'écran se ferme : plus aucun geste possible.
    final locked = state.busy || state.action == ReceptionAction.declined;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
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
          child: reception.isConfirmed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Le colis est encore en route : le destinataire écrit
                    // au voyageur dans une conversation à part, que
                    // l'expéditeur ne voit pas (lot 3C).
                    if (reception.canMessageTraveler) ...[
                      RecipientConversationLauncher(
                        bidId: reception.bidId,
                        role: RecipientConversationRole.recipient,
                        builder: (context, onPressed, isLoading) => DonyButton(
                          key: const Key('reception-message-traveler'),
                          label: l.receptionMessageTraveler,
                          iconAsset: 'message-circle',
                          flat: true,
                          isLoading: isLoading,
                          onPressed: onPressed,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.sm),
                    ],
                    DonyButton(
                      key: const Key('reception-view-tracking'),
                      label: l.receptionViewTracking,
                      iconAsset: 'route',
                      variant: DonyButtonVariant.secondary,
                      onPressed: () => openTimeline(context, reception),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DonyButton(
                      key: const Key('reception-confirm'),
                      label: l.receptionConfirmButton,
                      flat: true,
                      isLoading: state.action == ReceptionAction.confirming,
                      onPressed: locked
                          ? null
                          : () =>
                                context.read<ReceptionDetailCubit>().confirm(),
                    ),
                    const SizedBox(height: DonySpacing.sm),
                    DonyButton(
                      key: const Key('reception-decline'),
                      label: l.receptionDeclineButton,
                      variant: DonyButtonVariant.ghost,
                      isLoading: state.action == ReceptionAction.declining,
                      onPressed: locked ? null : () => _decline(context),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
