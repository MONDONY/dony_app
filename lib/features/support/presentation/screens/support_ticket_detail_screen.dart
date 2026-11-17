import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/support/bloc/support_bloc.dart';
import 'package:dony/features/support/bloc/support_contact_cubit.dart';
import 'package:dony/features/support/bloc/support_unread_cubit.dart';
import 'package:dony/features/support/data/support_attachment.dart';
import 'package:dony/features/support/data/support_models.dart';
import 'package:dony/features/support/presentation/screens/support_home_screen.dart';
import 'package:dony/features/support/presentation/widgets/support_attachment_picker.dart';
import 'package:dony/features/support/presentation/widgets/support_whatsapp_card.dart';
import 'package:dony/features/support/presentation/widgets/support_yadony_logo.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// Discussion « Support Yadony » : le fil d'un ticket, ou un fil neuf quand
/// [ticketId] est `null` (le premier message crée alors la demande). Lecture
/// seule quand le ticket est résolu, avec « Nouvelle demande » pour repartir
/// sur un fil neuf. L'en-tête porte l'icône WhatsApp de l'équipe.
class SupportTicketDetailScreen extends StatefulWidget {
  const SupportTicketDetailScreen({
    this.ticketId,
    this.contactCubit,
    super.key,
  });

  /// `null` : fil neuf, aucun ticket tant que rien n'est envoyé.
  final String? ticketId;

  /// Cubit du numéro WhatsApp fourni par l'appelant (tests) ; sinon créé et
  /// fermé par l'écran.
  final SupportContactCubit? contactCubit;

  @override
  State<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState extends State<SupportTicketDetailScreen> {
  final _messageController = TextEditingController();
  late final SupportContactCubit _contact;

  /// Garde-fou : le décrément de la pastille ne s'exécute qu'une seule fois
  /// par instance d'écran, même si le BLoC émet plusieurs états `ready`
  /// (ex. : cycle submitting → success d'un envoi de réponse).
  bool _unreadDeducted = false;

  @override
  void initState() {
    super.initState();
    _contact =
        widget.contactCubit ??
        (getIt<SupportContactCubit>()..load(source: 'support_chat'));
  }

  @override
  void dispose() {
    _messageController.dispose();
    if (widget.contactCubit == null) _contact.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        actions: [
          _WhatsAppAction(cubit: _contact),
          const DonyFeedbackButton(),
        ],
        leading: const DonyAppBarBackButton(),
        title: Row(
          children: [
            const SupportYadonyLogo(size: 34),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Text(
                context.l10n.supportBrandName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: BlocListener<SupportBloc, SupportState>(
        // Message reçu en direct sur ce fil (push au premier plan, bandeau
        // tu) : le fil est déjà marqué lu, on resynchronise le compteur
        // global et l'aperçu de la ligne épinglée.
        listenWhen: (previous, current) =>
            previous.liveRefreshCount != current.liveRefreshCount,
        listener: (_, _) => getIt<SupportUnreadCubit>().refresh(),
        child: BlocConsumer<SupportBloc, SupportState>(
          listener: (context, state) {
            if (state.sendStatus == SupportActionStatus.failure ||
                state.createStatus == SupportActionStatus.failure) {
              final message = supportErrorMessage(context.l10n, state);
              if (message != null) {
                DonySnackbar.show(
                  context,
                  message: message,
                  type: DonySnackbarType.error,
                );
              }
            }
            if (state.sendStatus == SupportActionStatus.success ||
                state.createStatus == SupportActionStatus.success) {
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
              getIt<SupportUnreadCubit>().decrementBy(
                state.ticket!.unreadCount,
              );
            }
          },
          builder: (context, state) {
            // Fil neuf : rien à charger, la discussion s'ouvre vide.
            final isNewThread =
                widget.ticketId == null &&
                state.detailStatus == SupportViewStatus.initial;
            if (isNewThread) {
              return _TicketThread(
                ticket: null,
                controller: _messageController,
                sending: state.createStatus == SupportActionStatus.submitting,
              );
            }
            return switch (state.detailStatus) {
              SupportViewStatus.initial || SupportViewStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              SupportViewStatus.failure => DonyEmptyState(
                type: DonyEmptyStateType.error,
                title: context.l10n.supportTicketNotFoundTitle,
                // `state.failure` est toujours renseigné dans cette branche :
                // `supportErrorMessage` n'y rend jamais `null` (relecture
                // finale H, Mineur #8). Pas de repli.
                description: supportErrorMessage(context.l10n, state),
                actionLabel: context.l10n.commonRetry,
                onAction: () => context.read<SupportBloc>().add(
                  SupportTicketDetailRequested(widget.ticketId!),
                ),
              ),
              // `ready` n'est émis qu'avec un ticket chargé, mais le repli
              // évite qu'une transition ajoutée plus tard ne fasse planter
              // l'écran.
              SupportViewStatus.ready =>
                state.ticket == null
                    ? const Center(child: CircularProgressIndicator())
                    : _TicketThread(
                        ticket: state.ticket,
                        controller: _messageController,
                        sending:
                            state.sendStatus == SupportActionStatus.submitting,
                      ),
            };
          },
        ),
      ),
    );
  }
}

/// Icône WhatsApp de l'en-tête : ouvre la conversation avec l'équipe. Absente
/// tant que le numéro n'est pas réglé dans l'admin (ou illisible).
class _WhatsAppAction extends StatelessWidget {
  const _WhatsAppAction({required this.cubit});

  final SupportContactCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportContactCubit, SupportContactState>(
      bloc: cubit,
      builder: (context, state) {
        if (state.status != SupportContactStatus.ready) {
          return const SizedBox.shrink();
        }
        return Semantics(
          button: true,
          label: context.l10n.supportWhatsappCta,
          excludeSemantics: true,
          child: GestureDetector(
            key: const Key('support-chat-whatsapp'),
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                openSupportWhatsApp(context, cubit, source: 'support_chat'),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kWhatsAppGreen,
                    borderRadius: BorderRadius.circular(DonyRadius.sm),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/logos/social/whatsapp.svg',
                      width: 20,
                      height: 20,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TicketThread extends StatelessWidget {
  const _TicketThread({
    required this.ticket,
    required this.controller,
    required this.sending,
  });

  /// `null` : fil neuf, aucun message ni statut à afficher.
  final SupportTicket? ticket;
  final TextEditingController controller;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ticket = this.ticket;
    final messages = ticket?.messages ?? const <SupportMessage>[];
    return Column(
      children: [
        if (ticket != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                DonyBadge(
                  label: SupportLabels.status(context.l10n, ticket.status),
                  type: SupportLabels.statusBadge(ticket.status),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    SupportLabels.category(context.l10n, ticket.category),
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
            itemCount: messages.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final message = messages[index];
              final previous = index == 0 ? null : messages[index - 1];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_startsNewDay(previous, message))
                    DonyChatDateSeparator(date: message.createdAt!),
                  _MessageBubble(message: message),
                ],
              );
            },
          ),
        ),
        if (ticket != null && ticket.isResolved)
          const _ResolvedBanner()
        else
          _MessageComposer(
            ticketId: ticket?.id,
            controller: controller,
            sending: sending,
          ),
      ],
    );
  }
}

/// Vrai quand [message] ouvre un nouveau jour : un message sans date n'ouvre
/// jamais de séparateur.
bool _startsNewDay(SupportMessage? previous, SupportMessage message) {
  final date = message.createdAt?.toLocal();
  if (date == null) return false;
  final before = previous?.createdAt?.toLocal();
  if (before == null) return true;
  return before.year != date.year ||
      before.month != date.month ||
      before.day != date.day;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fromUser = message.isFromUser;
    final sentAt = message.createdAt;
    final hasMeta = sentAt != null;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: DonyChatBubbleShell(
          isMe: fromUser,
          meta: hasMeta
              ? Text(
                  DateFormat.jm(
                    context.l10n.localeName,
                  ).format(sentAt.toLocal()),
                  style: tt.bodySmall?.copyWith(
                    fontSize: 10,
                    color: fromUser
                        ? cs.onPrimary.withValues(alpha: 0.75)
                        : cs.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                )
              : null,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, hasMeta ? 4 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!fromUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      context.l10n.supportBrandName,
                      style: tt.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (message.content.isNotEmpty)
                  Text(
                    message.content,
                    style: tt.bodyMedium?.copyWith(
                      color: fromUser ? cs.onPrimary : cs.onSurface,
                    ),
                  ),
                // Grille des images jointes. L'URL est présignée (expire en
                // 1 h) : on utilise Image.network qui maintient un cache
                // mémoire (keyed par URL). Aucun cache disque : les URLs
                // présignées expirent après 1 h, et une URL expirée en cache
                // disque retournerait un 403.
                if (message.attachments.isNotEmpty) ...[
                  if (message.content.isNotEmpty) const SizedBox(height: 6),
                  _AttachmentsGrid(message: message),
                ],
              ],
            ),
          ),
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
            label: context.l10n.supportViewImageLabel,
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
    final l = context.l10n;
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
                          l.supportPhotoIndex(i + 1, count),
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
                        label: l.commonClose,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.supportResolvedBannerMessage,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            DonyButton(
              key: const Key('support-thread-new-request'),
              label: context.l10n.supportNewRequestCta,
              // Remplace ce fil résolu par un fil neuf (nouveau bloc).
              onPressed: () => context.pushReplacement('/support/thread'),
            ),
          ],
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

  /// `null` : fil neuf, le premier message crée la demande.
  final String? ticketId;
  final TextEditingController controller;
  final bool sending;

  /// Catégorie des demandes ouvertes depuis la discussion (pas de choix de
  /// catégorie : un seul fil d'échange avec l'équipe).
  static const _newThreadCategory = 'OTHER';
  static const _maxSubjectLength = 200;

  void _send(BuildContext context, SupportState state) {
    final draft = controller.text;
    if (!state.canSendWith(draft) || sending) return;
    final id = ticketId;
    final content = draft.trim();
    if (id == null) {
      // Fil neuf : l'objet est la première ligne du message, tronquée.
      final firstLine = content.split('\n').first.trim();
      final subject = firstLine.length > _maxSubjectLength
          ? firstLine.substring(0, _maxSubjectLength)
          : firstLine;
      context.read<SupportBloc>().add(
        SupportTicketCreateRequested(
          category: _newThreadCategory,
          subject: subject.isEmpty ? context.l10n.supportBrandName : subject,
          message: content,
        ),
      );
      return;
    }
    context.read<SupportBloc>().add(
      SupportMessageSendRequested(ticketId: id, content: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportBloc, SupportState>(
      buildWhen: (prev, curr) =>
          prev.pendingAttachments != curr.pendingAttachments ||
          prev.sendStatus != curr.sendStatus ||
          prev.createStatus != curr.createStatus,
      builder: (context, state) {
        final atQuota =
            state.pendingAttachments.length >= SupportAttachmentActions.max;
        return DonyChatComposer(
          controller: controller,
          hintText: context.l10n.supportMessageHint,
          sending: sending,
          canSend: (draft) => state.canSendWith(draft) && !sending,
          onSend: () => _send(context, state),
          onSubmitted: (_) => _send(context, state),
          // Vignettes au-dessus de la pilule : à quatre images dans la même
          // rangée que le champ, il resterait moins de 20 px pour saisir.
          above: const SupportAttachmentStrip(),
          attach: DonyComposerAttach(
            onPlus: () => SupportAttachmentActions.showSourceSheet(context),
            onCamera: () =>
                SupportAttachmentActions.pick(context, ImageSource.camera),
            // Quota atteint, ou fil neuf (la demande part avec le texte seul) :
            // « + » et appareil photo grisés, sans action.
            onLocked: () {},
            locked: atQuota || ticketId == null,
          ),
        );
      },
    );
  }
}
