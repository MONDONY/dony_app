import 'package:dony/core/design/widgets/dony_button.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/package_request/bloc/negotiation_bloc.dart';
import 'package:dony/features/package_request/data/models/negotiation_message.dart';
import 'package:dony/features/package_request/data/models/negotiation_thread.dart';
import 'package:dony/features/package_request/presentation/_theme.dart';
import 'package:dony/features/package_request/presentation/widgets/accept_offer_bottom_sheet.dart';
import 'package:dony/features/package_request/presentation/widgets/counter_offer_bottom_sheet.dart';
import 'package:dony/features/package_request/presentation/widgets/reject_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
      ),
      body: BlocConsumer<NegotiationBloc, NegotiationState>(
        listener: (ctx, state) {
          if (state is NegotiationError) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: kError),
            );
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
          return _buildLoaded(context, thread, state is NegotiationActionInProgress);
        },
      ),
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    NegotiationThread thread,
    bool actionInProgress,
  ) {
    final isSender = thread.travelerId != viewerUserId;
    final canCounter = thread.status == NegotiationThreadStatus.open;
    final canAccept = canCounter && isSender;
    final canReject = canCounter;
    final lastFromMe = thread.messages.isNotEmpty &&
        thread.messages.last.fromUserId == viewerUserId;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: kSurface,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: kGreenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.handshake_rounded,
                    color: kGreenPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prix actuel : ${thread.currentPriceEur.toStringAsFixed(0)} €',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Round ${thread.roundsCount}/5 — ${_statusLabel(thread.status)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: kBorder),
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
                  20, 16, 20, MediaQuery.of(context).padding.bottom + 100),
              itemCount: thread.messages.length,
              itemBuilder: (context, i) {
                final m = thread.messages[i];
                final mine = m.fromUserId == viewerUserId;
                return _MessageBubble(message: m, mine: mine)
                    .animate()
                    .fadeIn(duration: 200.ms, delay: (40 * i).ms)
                    .slideY(begin: 0.05);
              },
            ),
          ),
        ),
        // ── AWAITING_TRIP : Traveler must link a trip ──────────────────────
        if (thread.status == NegotiationThreadStatus.awaitingTrip)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: !isSender
                  ? DonyButton(
                      label: 'Lier un trajet à cette offre',
                      onPressed: actionInProgress
                          ? null
                          : () => context.push(
                              '/negotiations/${thread.id}/link-trip',
                              extra: thread,
                            ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kGreenLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top_rounded,
                              color: kGreenPrimary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Le voyageur prépare son trajet…',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  color: kGreenDark),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          )
        // ── AWAITING_PAYMENT : Sender must pay ─────────────────────────────
        else if (thread.status == NegotiationThreadStatus.awaitingPayment)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: isSender
                  ? DonyButton(
                      label: 'Payer ${thread.currentPriceEur.toStringAsFixed(0)} €',
                      onPressed: actionInProgress
                          ? null
                          : () => AcceptOfferBottomSheet.show(
                              context,
                              bloc: context.read<NegotiationBloc>(),
                              threadId: thread.id,
                              priceEur: thread.currentPriceEur,
                              isCheckout: true),
                    )
                  : Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: kGreenLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.payments_outlined,
                              color: kGreenPrimary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'En attente du paiement de l\'expéditeur',
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  color: kGreenDark),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          )
        // ── ACCEPTED final ─────────────────────────────────────────────────
        else if (thread.status == NegotiationThreadStatus.accepted)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kSuccess.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: kSuccess),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Demande acceptée et payée',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600, color: kSuccess),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        // ── OPEN : Counter / Reject / Accept (sender) ──────────────────────
        else if (canCounter && !lastFromMe)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: canAccept
                  // SENDER: 3 actions — Accept full-width prominent + Counter/Reject side by side
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DonyButton(
                          label: 'Accepter ${thread.currentPriceEur.toStringAsFixed(0)} €',
                          onPressed: actionInProgress
                              ? null
                              : () => AcceptOfferBottomSheet.show(context,
                                  bloc: context.read<NegotiationBloc>(),
                                  threadId: thread.id,
                                  priceEur: thread.currentPriceEur),
                        ),
                        const SizedBox(height: 12),
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
                                        currentPriceEur: thread.currentPriceEur),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DonyButton(
                                label: 'Rejeter',
                                variant: DonyButtonVariant.ghost,
                                onPressed: actionInProgress
                                    ? null
                                    : () => RejectBottomSheet.show(context,
                                        bloc: context.read<NegotiationBloc>(),
                                        threadId: thread.id),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  // TRAVELER: 2 actions — Counter (primary) + Reject (secondary)
                  : Row(
                      children: [
                        Expanded(
                          child: DonyButton(
                            label: 'Rejeter',
                            variant: DonyButtonVariant.ghost,
                            onPressed: actionInProgress
                                ? null
                                : () => RejectBottomSheet.show(context,
                                    bloc: context.read<NegotiationBloc>(),
                                    threadId: thread.id),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DonyButton(
                            label: 'Contre-offre',
                            onPressed: actionInProgress
                                ? null
                                : () => CounterOfferBottomSheet.show(context,
                                    bloc: context.read<NegotiationBloc>(),
                                    threadId: thread.id,
                                    currentPriceEur: thread.currentPriceEur),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }

  String _statusLabel(NegotiationThreadStatus s) => switch (s) {
        NegotiationThreadStatus.open => 'En cours',
        NegotiationThreadStatus.awaitingTrip => 'Attente trajet voyageur',
        NegotiationThreadStatus.awaitingPayment => 'Attente paiement',
        NegotiationThreadStatus.accepted => 'Acceptée',
        NegotiationThreadStatus.rejected => 'Rejetée',
        NegotiationThreadStatus.autoRejected => 'Auto-rejetée',
        NegotiationThreadStatus.expired => 'Expirée',
      };
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});
  final NegotiationMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? kGreenPrimary : kSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: mine ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: mine ? const Radius.circular(4) : const Radius.circular(16),
          ),
          border: mine ? null : Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _kindLabel(message.kind),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: mine
                    ? Colors.white.withValues(alpha: 0.85)
                    : kTextSecondary,
                letterSpacing: 0.5,
              ),
            ),
            if (message.proposedPriceEur != null) ...[
              const SizedBox(height: 2),
              Text(
                '${message.proposedPriceEur!.toStringAsFixed(0)} €',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: mine ? Colors.white : kGreenPrimary,
                ),
              ),
            ],
            if (message.body != null && message.body!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                message.body!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: mine ? Colors.white : kTextPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _kindLabel(NegotiationMessageKind k) => switch (k) {
        NegotiationMessageKind.proposal => 'PROPOSITION',
        NegotiationMessageKind.counter => 'CONTRE-OFFRE',
        NegotiationMessageKind.accept => 'ACCEPTÉ',
        NegotiationMessageKind.reject => 'REJETÉ',
      };
}
