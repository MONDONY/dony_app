import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/linked_trip_card.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_hero_card.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_message_bubble.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_state_cta_bar.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/trip_detail_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class NegotiationThreadScreen extends StatelessWidget {
  const NegotiationThreadScreen({
    required this.threadId,
    required this.viewerUserId,
    super.key,
  });
  final String threadId;
  final String viewerUserId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<NegotiationBloc>()..add(NegotiationFetchRequested(threadId)),
      child: _ThreadView(threadId: threadId, viewerUserId: viewerUserId),
    );
  }
}

class _ThreadView extends StatelessWidget {
  const _ThreadView({required this.threadId, required this.viewerUserId});
  final String threadId;
  final String viewerUserId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NegotiationBloc, NegotiationState>(
      listener: (ctx, state) {
        if (state is NegotiationError) {
          if (state.error.code == 'negotiation/commission-charge-failed') {
            DonySnackbar.show(
              ctx,
              message:
                  'Le paiement cash est impossible : solde et carte du voyageur indisponibles.',
              type: DonySnackbarType.warning,
            );
            ctx.pop();
          } else {
            ErrorPresenter.show(ctx, state.error);
          }
        }
        if (state is NegotiationRejected) {
          DonySnackbar.show(
            ctx,
            message: 'Négociation rejetée',
            type: DonySnackbarType.warning,
          );
          ctx.pop();
        }
      },
      builder: (context, state) {
        NegotiationThread? thread;
        if (state is NegotiationLoaded) {
          thread = state.thread;
        }
        if (state is NegotiationActionInProgress) {
          thread = state.thread;
        }

        return Scaffold(
          backgroundColor: DonyColors.sand100,
          appBar: _buildAppBar(context, thread),
          body: thread == null
              ? const Center(
                  child: CircularProgressIndicator(color: DonyColors.primary))
              : _LoadedView(
                  thread: thread,
                  viewerUserId: viewerUserId,
                  actionInProgress: state is NegotiationActionInProgress,
                ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, NegotiationThread? thread) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.fromLTRB(DonySpacing.base, 0, DonySpacing.sm, 0),
        child: Row(
          children: [
            Builder(builder: (ctx) {
              final cs = Theme.of(ctx).colorScheme;
              return IconButton(
                tooltip: 'Retour',
                // Arrivée possible via go() (écran de succès post-acceptation) :
                // la pile est alors vide, pop() lèverait "nothing to pop".
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/negotiations'),
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                  ),
                  child: DonyIcon('chevron-left', size: 20, color: cs.primary),
                ),
              );
            }),
            const SizedBox(width: DonySpacing.sm + 2),
            if (thread != null) ...[
              _PartnerTitle(thread: thread, viewerUserId: viewerUserId),
            ] else ...[
              Text(
                'Négociation',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: DonyColors.textPrimary,
                    ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: DonySpacing.sm),
          child: IconButton(
            icon: const DonyIcon('ellipsis',
                color: DonyColors.textPrimary, size: 22),
            onPressed: () {},
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: DonyColors.neutral200),
      ),
    );
  }
}

// ── Partner title in AppBar ───────────────────────────────────────────────────
// Shows the OTHER party's name: if viewer is the traveler, show the sender;
// if viewer is the sender, show the traveler (with rating + trips count).

class _PartnerTitle extends StatelessWidget {
  const _PartnerTitle({required this.thread, required this.viewerUserId});
  final NegotiationThread thread;
  final String viewerUserId;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final bool iAmTraveler = viewerUserId == thread.travelerId;
    final String name = iAmTraveler
        ? (thread.senderName ?? 'Expéditeur')
        : (thread.travelerName ?? 'Voyageur');
    final double? rating = iAmTraveler ? null : thread.travelerRating;
    final int? trips = iAmTraveler ? null : thread.travelerTripsCount;
    final String? photoUrl = iAmTraveler ? thread.senderPhotoUrl : thread.travelerPhotoUrl;

    String meta = '';
    if (rating != null) {
      meta = '★${rating.toStringAsFixed(1)}';
      if (trips != null && trips > 0) {
        meta += ' · $trips trajets';
      }
    }

    return Row(
      children: [
        DonyAvatar(
          name: name,
          imageUrl: photoUrl,
          size: DonyAvatarSize.sm,
          verified: (trips ?? 0) > 0,
        ),
        const SizedBox(width: DonySpacing.sm + 2),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: DonyColors.textPrimary,
              ),
            ),
            if (meta.isNotEmpty)
              Text(
                meta,
                style: tt.bodySmall?.copyWith(
                  color: DonyColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  // Tabular figures: prevents layout shift as rating numbers update
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Loaded view ───────────────────────────────────────────────────────────────

class _LoadedView extends StatefulWidget {
  const _LoadedView({
    required this.thread,
    required this.viewerUserId,
    required this.actionInProgress,
  });

  final NegotiationThread thread;
  final String viewerUserId;
  final bool actionInProgress;

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  final _scrollController = ScrollController();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _lastMessageCount = widget.thread.messages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(_LoadedView old) {
    super.didUpdateWidget(old);
    if (widget.thread.messages.length != _lastMessageCount) {
      _lastMessageCount = widget.thread.messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thread = widget.thread;
    final viewerUserId = widget.viewerUserId;
    final actionInProgress = widget.actionInProgress;

    final variant = ThreadStatusVariant.fromThread(thread.status);
    final isLastFromOther = thread.messages.isNotEmpty &&
        thread.messages.last.fromUserId != viewerUserId;

    return Column(
      children: [
        ThreadHeroCard(
          thread: thread,
          statusVariant: variant,
          isTraveler: viewerUserId == thread.travelerId,
        )
            .animate()
            .fadeIn(duration: 220.ms)
            .slideY(begin: -0.04, curve: Curves.easeOutCubic),
        Expanded(
          child: RefreshIndicator(
            color: DonyColors.primary,
            onRefresh: () async {
              context
                  .read<NegotiationBloc>()
                  .add(NegotiationFetchRequested(thread.id));
            },
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                DonySpacing.base,
                DonySpacing.sm,
                DonySpacing.base,
                MediaQuery.of(context).padding.bottom + DonySpacing.base,
              ),
              itemCount: thread.messages.length,
              itemBuilder: (context, i) {
                final m = thread.messages[i];
                final mine = m.fromUserId == viewerUserId;
                final isLast = i == thread.messages.length - 1;
                final shouldHighlight = isLast &&
                    isLastFromOther &&
                    thread.status == NegotiationThreadStatus.open &&
                    _isProposalOrCounter(m.kind);
                return ThreadMessageBubble(
                  message: m,
                  mine: mine,
                  highlight: shouldHighlight,
                  isTraveler: viewerUserId == thread.travelerId,
                  grossPriceEur: thread.grossPriceEur,
                )
                    .animate()
                    .fadeIn(duration: 200.ms, delay: (40 * i).ms)
                    .slideY(begin: 0.05);
              },
            ),
          ),
        ),
        if (thread.linkedTrip != null)
          LinkedTripCard(
            trip: thread.linkedTrip!,
            onTap: () => TripDetailBottomSheet.show(
              context,
              trip: thread.linkedTrip!,
              isSender: viewerUserId != thread.travelerId,
              // Refus uniquement possible avant paiement
              onRefuse: thread.status ==
                      NegotiationThreadStatus.awaitingPayment
                  ? (reason) => context
                      .read<NegotiationBloc>()
                      .add(NegotiationRefuseTripRequested(
                          threadId: thread.id, reason: reason))
                  : null,
            ),
          ),
        ThreadStateCtaBar(
          thread: thread,
          viewerUserId: viewerUserId,
          actionInProgress: actionInProgress,
        ),
      ],
    );
  }

  bool _isProposalOrCounter(NegotiationMessageKind kind) =>
      kind == NegotiationMessageKind.proposal ||
      kind == NegotiationMessageKind.counter;
}
