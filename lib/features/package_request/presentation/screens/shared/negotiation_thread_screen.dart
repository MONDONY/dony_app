import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_hero_card.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_message_bubble.dart';
import 'package:dony/features/package_request/presentation/widgets/thread/thread_state_cta_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Écran d'un thread de négociation — refactorisé Phase 3.
///
/// Match maquettes v3 (20-44-27 → 20-45-14) :
/// - Hero card coloré selon status (5 tints : ink/amber/violet/green/grey)
/// - ListView de bubbles structurées (mine vs them, 4 kinds)
/// - CTAs contextuels par (status × isSender × lastFromMe)
///
/// La logique BLoC est INCHANGÉE — seul le rendu est rewriten.
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
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              size: 20, color: kGreenPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Négociation',
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: BlocConsumer<NegotiationBloc, NegotiationState>(
        listener: (ctx, state) {
          if (state is NegotiationError) {
            ErrorPresenter.show(ctx, state.error);
          }
          if (state is NegotiationRejected) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Négociation rejetée')),
            );
            ctx.pop();
          }
        },
        builder: (context, state) {
          NegotiationThread? thread;
          if (state is NegotiationLoaded) thread = state.thread;
          if (state is NegotiationActionInProgress) thread = state.thread;

          if (thread == null) {
            return const Center(
                child: CircularProgressIndicator(color: kGreenPrimary));
          }
          return _LoadedView(
            thread: thread,
            viewerUserId: viewerUserId,
            actionInProgress: state is NegotiationActionInProgress,
          );
        },
      ),
    );
  }
}

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
            color: kGreenPrimary,
            onRefresh: () async {
              context
                  .read<NegotiationBloc>()
                  .add(NegotiationFetchRequested(thread.id));
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                  20, 4, 20, MediaQuery.of(context).padding.bottom + 16),
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
