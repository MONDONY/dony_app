import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_hero_card.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_message_bubble.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_state_cta_bar.dart';
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
          ErrorPresenter.show(ctx, state.error);
        }
        if (state is NegotiationRejected) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('Négociation rejetée'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          ctx.pop();
        }
      },
      builder: (context, state) {
        NegotiationThread? thread;
        if (state is NegotiationLoaded) thread = state.thread;
        if (state is NegotiationActionInProgress) thread = state.thread;

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
                onPressed: () => context.pop(),
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                  ),
                  child: Icon(Icons.chevron_left_rounded, size: 20, color: cs.primary),
                ),
              );
            }),
            const SizedBox(width: DonySpacing.sm + 2),
            if (thread != null) ...[
              _TravelerTitle(thread: thread),
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
            icon: const Icon(Icons.more_horiz_rounded,
                color: DonyColors.textPrimary, size: 22),
            onPressed: () {},
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: DonyColors.neutral200),
      ),
    );
  }
}

// ── Traveler title in AppBar ──────────────────────────────────────────────────

class _TravelerTitle extends StatelessWidget {
  const _TravelerTitle({required this.thread});
  final NegotiationThread thread;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final name = thread.travelerName ?? 'Voyageur';
    final rating = thread.travelerRating;
    final trips = thread.travelerTripsCount;

    String meta = '';
    if (rating != null) {
      meta = '★${rating.toStringAsFixed(1)}';
      if (trips != null && trips > 0) meta += ' · $trips trajets';
    }

    return Row(
      children: [
        DonyAvatar(
          name: name,
          imageUrl: thread.travelerPhotoUrl,
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
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Loaded view ───────────────────────────────────────────────────────────────

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.thread,
    required this.viewerUserId,
    required this.actionInProgress,
  });

  final NegotiationThread thread;
  final String viewerUserId;
  final bool actionInProgress;

  @override
  Widget build(BuildContext context) {
    final variant = ThreadStatusVariant.fromThread(thread.status);
    final isLastFromOther = thread.messages.isNotEmpty &&
        thread.messages.last.fromUserId != viewerUserId;

    return Column(
      children: [
        ThreadHeroCard(thread: thread, statusVariant: variant)
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
                )
                    .animate()
                    .fadeIn(duration: 200.ms, delay: (40 * i).ms)
                    .slideY(begin: 0.05);
              },
            ),
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
