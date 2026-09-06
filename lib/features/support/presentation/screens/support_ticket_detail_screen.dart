import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/bloc/support_unread_cubit.dart';
import 'package:dony/features/support/data/support_attachment.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/presentation/screens/support_home_screen.dart';
import 'package:dony/features/support/presentation/widgets/support_attachment_picker.dart';
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

  /// Garde-fou : le décrément de la pastille ne s'exécute qu'une seule fois
  /// par instance d'écran, même si le BLoC émet plusieurs états `ready`
  /// (ex. : cycle submitting → success d'un envoi de réponse).
  bool _unreadDeducted = false;

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
          // À l'ouverture du fil, éteindre la pastille sans attendre le
          // serveur : le BLoC a déjà marqué les messages comme lus (Task 9).
          // Le flag _unreadDeducted garantit que le décrément ne s'exécute
          // qu'une fois par instance d'écran, même si le BLoC réémet un état
          // `ready` lors d'un cycle sendStatus (submitting → success).
          if (!_unreadDeducted &&
              state.detailStatus == SupportViewStatus.ready &&
              state.ticket != null &&
              state.ticket!.unreadCount > 0) {
            _unreadDeducted = true;
            getIt<SupportUnreadCubit>().decrementBy(state.ticket!.unreadCount);
          }
        },
        builder: (context, state) => switch (state.detailStatus) {
          SupportViewStatus.initial || SupportViewStatus.loading =>
            const Center(child: CircularProgressIndicator()),
          SupportViewStatus.failure => DonyEmptyState(
            type: DonyEmptyStateType.error,
            title: 'Ticket introuvable',
            description:
                state.errorMessage ?? 'Vérifiez votre connexion et réessayez.',
            actionLabel: 'Réessayer',
            onAction: () => context.read<SupportBloc>().add(
              SupportTicketDetailRequested(widget.ticketId),
            ),
          ),
          // `ready` n'est émis qu'avec un ticket chargé, mais le repli évite
          // qu'une transition ajoutée plus tard ne fasse planter l'écran.
          SupportViewStatus.ready =>
            state.ticket == null
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
            if (message.content.isNotEmpty)
              Text(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: fromUser ? cs.onPrimary : cs.onSurface,
                ),
              ),
            // Grille des images jointes. L'URL est présignée (expire en 1 h) :
            // on utilise Image.network qui maintient un cache mémoire (keyed
            // par URL). Aucun cache disque : les URLs présignées expirent après
            // 1 h, et une URL expirée en cache disque retournerait un 403.
            if (message.attachments.isNotEmpty) ...[
              if (message.content.isNotEmpty) const SizedBox(height: 6),
              _AttachmentsGrid(message: message),
            ],
          ],
        ),
      ),
    );
  }
}

/// Grille d'images jointes à un message.
///
/// Choix de rendu : [Image.network] au lieu de [CachedNetworkImage] pour
/// éviter la mise en cache des URLs présignées qui expirent en 1 h. Chaque
/// rechargement du fil obtient de nouvelles URLs du backend, ce qui garantit
/// que l'utilisateur voit toujours des images valides. La mise en cache sur
/// disque d'une URL expirée retournerait une erreur 403 à la prochaine session.
class _AttachmentsGrid extends StatelessWidget {
  const _AttachmentsGrid({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final attachments = message.attachments;
    return Wrap(
      spacing: DonySpacing.xs,
      runSpacing: DonySpacing.xs,
      children: [
        for (final att in attachments)
          Semantics(
            button: true,
            label: 'Voir l\'image en plein ecran',
            child: GestureDetector(
              onTap: () => _openViewer(context, attachments, att.id),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DonyRadius.sm),
                child: Image.network(
                  att.url,
                  key: Key('support-attachment-${att.id}'),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: 80,
                      height: 80,
                      color: cs.surfaceContainerHighest,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => Container(
                    width: 80,
                    height: 80,
                    color: cs.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: cs.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openViewer(
    BuildContext context,
    List<SupportAttachment> attachments,
    String currentId,
  ) {
    final initialIndex = attachments
        .indexWhere((a) => a.id == currentId)
        .clamp(0, attachments.length - 1);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _SupportImageViewer(
        attachments: message.attachments,
        initialIndex: initialIndex,
      ),
    );
  }
}

/// Visionneuse plein écran (modale) des images support.
///
/// Reprend le pattern de [BidPhotoViewerModal] : swipe, dots, compteur, fermeture.
/// Utilise [Image.network] (pas de cache sur URL présignée volatile).
class _SupportImageViewer extends StatefulWidget {
  const _SupportImageViewer({required this.attachments, this.initialIndex = 0});

  final List<SupportAttachment> attachments;
  final int initialIndex;

  @override
  State<_SupportImageViewer> createState() => _SupportImageViewerState();
}

class _SupportImageViewerState extends State<_SupportImageViewer> {
  late final PageController _controller;
  late final ValueNotifier<int> _index;

  @override
  void initState() {
    super.initState();
    _index = ValueNotifier<int>(widget.initialIndex);
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = widget.attachments.length;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: DonySpacing.base),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: _index,
                        builder: (_, i, _) => Text(
                          'Photo ${i + 1} / $count',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Semantics(
                        button: true,
                        container: true,
                        excludeSemantics: true,
                        label: 'Fermer',
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DonySpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(DonyRadius.card),
                    child: SizedBox(
                      height: 300,
                      width: double.infinity,
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: count,
                        onPageChanged: (i) => _index.value = i,
                        itemBuilder: (_, i) => Image.network(
                          widget.attachments[i].url,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: cs.primary,
                              ),
                            );
                          },
                          errorBuilder: (_, _, _) => Icon(
                            Icons.broken_image_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (count > 1) ...[
                    const SizedBox(height: 12),
                    ValueListenableBuilder<int>(
                      valueListenable: _index,
                      builder: (_, current, _) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < count; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 3.5,
                              ),
                              width: i == current ? 20 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == current
                                    ? cs.primary
                                    : cs.outline.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatefulWidget {
  const _MessageComposer({
    required this.ticketId,
    required this.controller,
    required this.sending,
  });

  final String ticketId;
  final TextEditingController controller;
  final bool sending;

  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  /// Brouillon courant — réévalué à chaque frappe pour que le bouton d'envoi
  /// reflète [SupportState.canSendWith] correctement.
  String _draft = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() => _draft = widget.controller.text);
  }

  void _send(BuildContext context, SupportState state) {
    if (!state.canSendWith(_draft) || widget.sending) return;
    context.read<SupportBloc>().add(
      SupportMessageSendRequested(ticketId: widget.ticketId, content: _draft),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<SupportBloc, SupportState>(
      buildWhen: (prev, curr) =>
          prev.pendingAttachments != curr.pendingAttachments ||
          prev.sendStatus != curr.sendStatus,
      builder: (context, state) {
        final canSend = state.canSendWith(_draft) && !widget.sending;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              12 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vignettes + trombone (seulement si des images sont en attente
                // ou toujours — le picker gère lui-même son état vide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Trombone (désactivé à 4 images)
                    SupportAttachmentPicker(ticketId: widget.ticketId),
                    const SizedBox(width: 4),
                    Expanded(
                      child: DonyTextField(
                        controller: widget.controller,
                        hint: 'Votre message',
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _send(context, state),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: widget.sending
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : IconButton.filled(
                              onPressed: canSend
                                  ? () => _send(context, state)
                                  : null,
                              tooltip: 'Envoyer',
                              icon: Icon(
                                Icons.send_rounded,
                                color: cs.onPrimary,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
