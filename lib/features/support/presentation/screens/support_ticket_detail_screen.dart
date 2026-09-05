import 'package:dony/core/design/widgets/dony_app_bar.dart';
import 'package:dony/core/design/widgets/dony_badge.dart';
import 'package:dony/core/design/widgets/dony_empty_state.dart';
import 'package:dony/core/design/widgets/dony_snackbar.dart';
import 'package:dony/core/design/widgets/dony_text_field.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/presentation/screens/support_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Fil d'un ticket support. Lecture seule quand le ticket est résolu : un
/// nouveau problème passe par un nouveau ticket.
class SupportTicketDetailScreen extends StatefulWidget {
  const SupportTicketDetailScreen({required this.ticketId, super.key});

  final String ticketId;

  @override
  State<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const DonyAppBarBackButton(),
        title: BlocBuilder<SupportBloc, SupportState>(
          builder: (context, state) =>
              Text(state.ticket?.subject ?? 'Ticket support'),
        ),
      ),
      body: BlocConsumer<SupportBloc, SupportState>(
        listener: (context, state) {
          if (state.sendStatus == SupportActionStatus.failure &&
              state.errorMessage != null) {
            DonySnackbar.show(
              context,
              message: state.errorMessage!,
              type: DonySnackbarType.error,
            );
          }
          if (state.sendStatus == SupportActionStatus.success) {
            _messageController.clear();
          }
        },
        builder: (context, state) => switch (state.detailStatus) {
          SupportViewStatus.initial ||
          SupportViewStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          SupportViewStatus.failure => DonyEmptyState(
              type: DonyEmptyStateType.error,
              title: 'Ticket introuvable',
              description: state.errorMessage ??
                  'Vérifiez votre connexion et réessayez.',
              actionLabel: 'Réessayer',
              onAction: () => context
                  .read<SupportBloc>()
                  .add(SupportTicketDetailRequested(widget.ticketId)),
            ),
          // `ready` n'est émis qu'avec un ticket chargé, mais le repli évite
          // qu'une transition ajoutée plus tard ne fasse planter l'écran.
          SupportViewStatus.ready => state.ticket == null
              ? const Center(child: CircularProgressIndicator())
              : _TicketThread(
                  ticket: state.ticket!,
                  controller: _messageController,
                  sending: state.sendStatus == SupportActionStatus.submitting,
                ),
        },
      ),
    );
  }
}

class _TicketThread extends StatelessWidget {
  const _TicketThread({
    required this.ticket,
    required this.controller,
    required this.sending,
  });

  final SupportTicket ticket;
  final TextEditingController controller;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              DonyBadge(
                label: SupportLabels.status(ticket.status),
                type: SupportLabels.statusBadge(ticket.status),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  SupportLabels.category(ticket.category),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            itemCount: ticket.messages.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _MessageBubble(message: ticket.messages[index]),
          ),
        ),
        if (ticket.isResolved)
          const _ResolvedBanner()
        else
          _MessageComposer(
            ticketId: ticket.id,
            controller: controller,
            sending: sending,
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fromUser = message.isFromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromUser ? cs.primary : cs.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromUser ? 16 : 4),
            bottomRight: Radius.circular(fromUser ? 4 : 16),
          ),
          border: fromUser ? null : Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!fromUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'Support Yadony',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            Text(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: fromUser ? cs.onPrimary : cs.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolvedBanner extends StatelessWidget {
  const _ResolvedBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Ce ticket est résolu. Un autre problème ? Ouvrez un nouveau '
          'ticket depuis la page Support.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.ticketId,
    required this.controller,
    required this.sending,
  });

  final String ticketId;
  final TextEditingController controller;
  final bool sending;

  void _send(BuildContext context) {
    final content = controller.text.trim();
    if (content.isEmpty || sending) {
      return;
    }
    context.read<SupportBloc>().add(
          SupportMessageSendRequested(ticketId: ticketId, content: content),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: DonyTextField(
                controller: controller,
                hint: 'Votre message',
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => _send(context),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: sending
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  : IconButton.filled(
                      onPressed: () => _send(context),
                      tooltip: 'Envoyer',
                      icon: Icon(Icons.send_rounded, color: cs.onPrimary),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
