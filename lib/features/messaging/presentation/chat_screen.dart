import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/config/sms_auth_flag.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/services/analytics_events.dart';
import 'package:dony/core/services/analytics_service.dart';
import 'package:dony/core/utils/phone_dialer.dart';
import 'package:dony/core/widgets/dony_emoji.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/incident_report/data/repositories/incident_report_repository.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_bloc.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_event.dart';
import 'package:dony/features/matching/bloc/contact_reveal/contact_reveal_state.dart';
import 'package:dony/features/matching/presentation/widgets/block_user_action.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/data/chat_message_validator.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;

  /// Détourne la navigation en test. En production, laisser `null` :
  /// `_navigate` retombe alors sur `context.push`, conformément à la règle
  /// GoRouter du projet.
  final void Function(String path, Object? extra)? onNavigate;

  const ChatScreen({
    super.key,
    required this.conversation,
    this.onNavigate,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _validator = ChatMessageValidator();

  /// Envois récents de l'utilisateur — débit (5/15 s) + anti-doublon (30 s).
  final List<SentRecord> _recentSends = [];
  bool _isSending = false;

  String get _myUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(
      ChatSubscribeRequested(
        widget.conversation.firestoreConversationId,
        currentUserUid: _myUid,
        isReadOnly: widget.conversation.readOnly,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        getIt<AnalyticsService>().logEvent(
          AnalyticsEvents.conversationOpened,
          properties: {'context': 'conversation'},
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _navigate(String path, Object? extra) {
    final override = widget.onNavigate;
    if (override != null) {
      override(path, extra);
      return;
    }
    context.push(path, extra: extra);
  }

  void _confirmAndDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la conversation'),
        content: const Text(
          'Cette conversation sera définitivement supprimée pour vous et votre interlocuteur. Impossible de la recréer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<ChatBloc>().add(
                ChatConversationDeleteRequested(
                  conversationId: widget.conversation.id,
                  firestoreConversationId:
                      widget.conversation.firestoreConversationId,
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _requestCall() {
    unawaited(
      getIt<AnalyticsService>().logEvent(
        AnalyticsEvents.conversationCallInitiated,
      ),
    );
    // Le numéro n'est plus dans la conversation : on le demande au serveur, qui
    // vérifie que le deal est actif et journalise la révélation.
    context.read<ContactRevealBloc>().add(
      ContactRevealRequested(widget.conversation.bidId),
    );
  }

  Future<void> _sendText() async {
    if (_isSending) return;
    final raw = _controller.text;
    final now = DateTime.now();

    // Règles de contenu (cf. ChatMessageValidator) — bloque + avertit.
    final result = _validator.validate(raw, recent: _recentSends, now: now);
    if (result is ChatValidationBlocked) {
      if (result.message.isNotEmpty) {
        DonySnackbar.show(
          context,
          message: result.message,
          type: DonySnackbarType.warning,
        );
        unawaited(
          getIt<AnalyticsService>().logEvent(
            AnalyticsEvents.messageBlocked,
            properties: {'reason': result.reason},
          ),
        );
      }
      return;
    }
    final text = (result as ChatValidationOk).text;

    setState(() => _isSending = true);
    _controller.clear();
    _recentSends.add(SentRecord(now, text));
    // Borne la liste (fenêtre la plus longue = anti-doublon 30 s).
    _recentSends.removeWhere(
      (r) => now.difference(r.at) > const Duration(seconds: 30),
    );

    context.read<ChatBloc>().add(
      ChatTextSendRequested(
        firestoreConversationId: widget.conversation.firestoreConversationId,
        conversationId: widget.conversation.id,
        senderFirebaseUid: _myUid,
        body: text,
      ),
    );
    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final conversation = widget.conversation;
    final participant = conversation.otherParticipant;
    // Le canal SMS OTP coupé n'empêche pas d'appeler (fonctionnalité
    // indépendante), mais tant qu'il l'est le concept même de "numéro" reste
    // masqué partout dans l'app — bouton retiré pour rester cohérent.
    final canCall =
        participant.phoneAvailable && smsAuthEnabledListenable.value;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: const DonyAppBarBackButton(),
        title: Row(
          children: [
            DonyAvatar(
              name: participant.name.isNotEmpty ? participant.name : '?',
              imageUrl: participant.avatarUrl,
              size: DonyAvatarSize.sm,
              verified: participant.kycVerified,
            ),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    participant.name.isNotEmpty
                        ? participant.name
                        : 'Conversation',
                    style: tt.titleLarge?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (participant.role != null && participant.role!.isNotEmpty)
                    Text(
                      participant.role!,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (canCall)
            BlocConsumer<ContactRevealBloc, ContactRevealState>(
              listener: (context, state) {
                if (state is ContactRevealSuccess) {
                  unawaited(dialPhoneNumber(context, state.phoneNumber));
                } else if (state is ContactRevealError) {
                  DonySnackbar.show(
                    context,
                    message: state.error.message,
                    type: DonySnackbarType.error,
                  );
                }
              },
              builder: (context, state) {
                final isRevealing = state is ContactRevealLoading;
                return IconButton(
                  tooltip: 'Appeler',
                  onPressed: isRevealing ? null : _requestCall,
                  icon: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                    ),
                    child: isRevealing
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          )
                        : DonyIcon('phone', size: 18, color: cs.primary),
                  ),
                );
              },
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'report':
                  _navigate('/settings/report-incident', {
                    'targetType': IncidentTargetType.user,
                    'targetId': participant.id,
                  });
                case 'block':
                  showBlockMenu(
                    context,
                    userId: participant.id,
                    displayName: participant.name,
                  );
                case 'delete':
                  _confirmAndDelete();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    DonyIcon('flag', size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: DonySpacing.sm),
                    Flexible(
                      child: Text(
                        'Signaler ${participant.name}',
                        style: tt.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    DonyIcon('ban', size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: DonySpacing.sm),
                    Flexible(
                      child: Text(
                        'Bloquer ${participant.name}',
                        style: tt.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    DonyIcon('trash-2', size: 20, color: cs.error),
                    const SizedBox(width: DonySpacing.sm),
                    Flexible(
                      child: Text(
                        'Supprimer la conversation',
                        style: tt.bodyMedium?.copyWith(color: cs.error),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outlineVariant),
        ),
      ),
      body: BlocConsumer<ChatBloc, ChatState>(
        listenWhen: (_, current) =>
            current is ChatConversationDeleted || current is ChatError,
        listener: (context, state) {
          if (state is ChatConversationDeleted) {
            getIt<ConversationListBloc>().add(
              ConversationRemovedLocally(widget.conversation.id),
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              DonySnackbar.show(context, message: 'Conversation supprimée');
              if (context.canPop()) context.pop();
            });
          } else if (state is ChatError) {
            ErrorPresenter.show(context, state.error);
          }
        },
        builder: (context, state) {
          final isReadOnly = state is ChatReadOnly;
          return Column(
            children: [
              if (conversation.tripLabel != null)
                _TripBanner(
                  conversation: conversation,
                  cs: cs,
                  tt: tt,
                  disabled: isReadOnly,
                ),
              if (isReadOnly) _ReadOnlyBanner(cs: cs, tt: tt),
              if (conversation.bidStatus != null)
                _BidStatusBanner(
                  status: conversation.bidStatus!,
                  cs: cs,
                  tt: tt,
                ),

              Expanded(
                child: Builder(
                  builder: (context) {
                    if (state is ChatLoading || state is ChatInitial) {
                      return const DonyChatSkeleton();
                    }
                    if (state is ChatError) {
                      return DonyEmptyState(
                        type: DonyEmptyStateType.error,
                        mascotte: DonyMascotteType.erreurLegere,
                        iconAsset: 'wifi-off',
                        title: 'Connexion interrompue',
                        description: ErrorPresenter.resolve(
                          state.error,
                        ).message,
                        actionLabel: 'Réessayer',
                        onAction: () => context.read<ChatBloc>().add(
                          ChatSubscribeRequested(
                            widget.conversation.firestoreConversationId,
                          ),
                        ),
                      );
                    }

                    final messages = switch (state) {
                      ChatLoaded(:final messages) => messages,
                      ChatReadOnly(:final messages) => messages,
                      _ => null,
                    };

                    if (messages != null) {
                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DonyIcon(
                                'message-circle',
                                size: 48,
                                color: cs.onSurfaceVariant.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                              const SizedBox(height: DonySpacing.md),
                              Text(
                                'Démarrez la conversation !',
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(
                          DonySpacing.lg,
                          DonySpacing.sm,
                          DonySpacing.lg,
                          DonySpacing.md,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message.senderId == _myUid;
                          final showSep = _showDateSeparator(messages, index);
                          // Dernier d'un groupe (visuellement en bas du groupe) :
                          // le message plus récent (index-1) a un autre expéditeur,
                          // ou c'est le plus récent, ou un séparateur les coupe.
                          final isLastOfGroup =
                              index == 0 ||
                              messages[index - 1].senderId !=
                                  message.senderId ||
                              _showDateSeparator(messages, index - 1);
                          return Column(
                            children: [
                              if (showSep)
                                _DateSeparator(
                                  date: message.sentAt,
                                  cs: cs,
                                  tt: tt,
                                ),
                              _MessageBubble(
                                    message: message,
                                    isMe: isMe,
                                    isLastOfGroup: isLastOfGroup,
                                  )
                                  .animate()
                                  .fadeIn(
                                    duration: 180.ms,
                                    curve: Curves.easeOutCubic,
                                  )
                                  .slideY(
                                    begin: 0.06,
                                    end: 0,
                                    duration: 180.ms,
                                    curve: Curves.easeOutCubic,
                                  ),
                            ],
                          );
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),

              _InputBar(
                controller: _controller,
                isSending: _isSending,
                disabled: isReadOnly,
                onSendText: _sendText,
              ),
            ],
          );
        },
      ),
    );
  }

  bool _showDateSeparator(List<MessageModel> messages, int index) {
    if (index < 0 || index >= messages.length) return false;
    if (index == messages.length - 1) return true;
    final current = messages[index].sentAt;
    final next = messages[index + 1].sentAt;
    return current.year != next.year ||
        current.month != next.month ||
        current.day != next.day;
  }
}

// ── Read-only info banner ──────────────────────────────────────────────────────

class _ReadOnlyBanner extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;
  const _ReadOnlyBanner({required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.lg,
        vertical: DonySpacing.sm,
      ),
      child: Row(
        children: [
          DonyIcon('lock', size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: DonySpacing.xs),
          Expanded(
            child: Text(
              'Votre interlocuteur a quitté cette conversation. Vous êtes en lecture seule.',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trip banner ────────────────────────────────────────────────────────────────

class _TripBanner extends StatelessWidget {
  final ConversationModel conversation;
  final ColorScheme cs;
  final TextTheme tt;
  final bool disabled;

  const _TripBanner({
    required this.conversation,
    required this.cs,
    required this.tt,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: disabled ? cs.surfaceContainerLowest : cs.surface,
      child: InkWell(
        onTap: disabled
            ? null
            : () => context.push('/bids/${conversation.bidId}'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg,
                10,
                DonySpacing.sm,
                10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(DonyRadius.sm),
                    ),
                    child: DonyIcon('plane', size: 16, color: cs.primary),
                  ),
                  const SizedBox(width: DonySpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Trajet lié',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          conversation.tripLabel!,
                          style: tt.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  DonyIcon(
                    'chevron-right',
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
          ],
        ),
      ),
    );
  }
}

// ── Bid status banner ──────────────────────────────────────────────────────────

class _BidStatusBanner extends StatelessWidget {
  final String status;
  final ColorScheme cs;
  final TextTheme tt;

  const _BidStatusBanner({
    required this.status,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final (String, Color, String?)? config = switch (status) {
      'BID_ACCEPTED' => ('Offre acceptée', cs.success, 'circle-check'),
      'DELIVERY_CONFIRMED' => ('Livraison confirmée', cs.success, 'package'),
      'TRIP_CANCELLED' => ('Trajet annulé', cs.error, 'circle-x'),
      _ => null,
    };
    if (config == null) return const SizedBox.shrink();

    final (label, color, iconAsset) = config;
    return Container(
      color: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.lg,
        vertical: DonySpacing.xs,
      ),
      child: Row(
        children: [
          if (iconAsset == 'package')
            const DonyEmoji.parcel(size: 14)
          else if (iconAsset != null)
            DonyIcon(iconAsset, size: 14, color: color),
          const SizedBox(width: DonySpacing.xs),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date separator ─────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  final ColorScheme cs;
  final TextTheme tt;

  const _DateSeparator({
    required this.date,
    required this.cs,
    required this.tt,
  });

  String _label() {
    final now = DateTime.now();
    final isToday =
        now.year == date.year && now.month == date.month && now.day == date.day;
    final isYesterday = now.difference(date).inDays == 1;
    if (isToday) return 'Aujourd\'hui';
    if (isYesterday) return 'Hier';
    return DateFormat('d MMMM y', 'fr').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.md,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(DonyRadius.full),
          ),
          child: Text(
            _label(),
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isLastOfGroup;
  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.isLastOfGroup = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (message.type == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: DonySpacing.sm),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.md,
              vertical: DonySpacing.xs,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: Text(
              message.isDeleted ? 'Message supprimé' : (message.body ?? ''),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Coin « queue » uniquement sur le dernier d'un groupe.
    final tail = Radius.circular(
      isLastOfGroup ? DonyRadius.xs : DonyRadius.card,
    );
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(DonyRadius.card),
      topRight: const Radius.circular(DonyRadius.card),
      bottomLeft: isMe ? const Radius.circular(DonyRadius.card) : tail,
      bottomRight: isMe ? tail : const Radius.circular(DonyRadius.card),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isLastOfGroup ? DonySpacing.sm : 2),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isMe ? cs.primary : cs.surface,
                      borderRadius: radius,
                      // Bulle reçue : ombre douce, SANS bordure (principe
                      // « ombres > bordures »). Bulle envoyée : aplat coloré.
                      boxShadow: isMe
                          ? null
                          : [
                              const BoxShadow(
                                color: DonyColors.shadow,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                    ),
                    child: message.isDeleted
                        ? _DeletedContent(isMe: isMe, cs: cs, tt: tt)
                        : message.type == MessageType.image
                        ? _ImageContent(imageUrl: message.imageUrl)
                        : message.type == MessageType.location
                        ? _LocationContent(
                            latitude: message.latitude ?? 0,
                            longitude: message.longitude ?? 0,
                            isMe: isMe,
                            cs: cs,
                            tt: tt,
                          )
                        : _TextContent(
                            body: message.body ?? '',
                            isMe: isMe,
                            cs: cs,
                            tt: tt,
                          ),
                  ),
                  // Horodatage + accusé : seulement sur le dernier du groupe.
                  if (isLastOfGroup) ...[
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('HH:mm').format(message.sentAt.toLocal()),
                          style: tt.bodySmall?.copyWith(
                            fontSize: 10,
                            color: cs.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          DonyIcon(
                            message.readAt != null ? 'check-check' : 'check',
                            size: 12,
                            color: message.readAt != null
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bubble content widgets ─────────────────────────────────────────────────────

class _TextContent extends StatelessWidget {
  final String body;
  final bool isMe;
  final ColorScheme cs;
  final TextTheme tt;
  const _TextContent({
    required this.body,
    required this.isMe,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.sm,
      ),
      child: Text(
        body,
        style: tt.bodyMedium?.copyWith(
          color: isMe ? cs.onPrimary : cs.onSurface,
        ),
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  final String? imageUrl;
  const _ImageContent({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(DonyRadius.card - 1),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        cacheKey: DonyImage.stableCacheKey(imageUrl!),
        width: 220,
        height: 180,
        fit: BoxFit.cover,
        placeholder: (_, _) => Builder(
          builder: (context) => Container(
            width: 220,
            height: 180,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, _, _) => Builder(
          builder: (context) {
            final cs = Theme.of(context).colorScheme;
            return Container(
              width: 220,
              height: 180,
              color: cs.surfaceContainerHighest,
              child: DonyIcon('image-off', color: cs.onSurfaceVariant),
            );
          },
        ),
      ),
    );
  }
}

class _LocationContent extends StatelessWidget {
  final double latitude;
  final double longitude;
  final bool isMe;
  final ColorScheme cs;
  final TextTheme tt;

  const _LocationContent({
    required this.latitude,
    required this.longitude,
    required this.isMe,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon('map-pin', size: 20, color: isMe ? cs.onPrimary : cs.error),
          const SizedBox(width: DonySpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Localisation partagée',
                style: tt.bodySmall?.copyWith(
                  color: isMe ? cs.onPrimary : cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
                style: tt.labelSmall?.copyWith(
                  color: isMe
                      ? cs.onPrimary.withValues(alpha: 0.65)
                      : cs.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeletedContent extends StatelessWidget {
  final bool isMe;
  final ColorScheme cs;
  final TextTheme tt;
  const _DeletedContent({
    required this.isMe,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.md,
        vertical: DonySpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyIcon(
            'ban',
            size: 14,
            color: isMe
                ? cs.onPrimary.withValues(alpha: 0.6)
                : cs.onSurfaceVariant,
          ),
          const SizedBox(width: DonySpacing.xs),
          Text(
            'Message supprimé',
            style: tt.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: isMe
                  ? cs.onPrimary.withValues(alpha: 0.6)
                  : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar (F1 — texte uniquement) ──────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool disabled;
  final VoidCallback onSendText;

  const _InputBar({
    required this.controller,
    required this.isSending,
    this.disabled = false,
    required this.onSendText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    if (disabled) {
      return Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        padding: EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.sm,
          DonySpacing.lg,
          DonySpacing.sm + MediaQuery.of(context).padding.bottom,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DonyIcon('lock', size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: DonySpacing.xs),
            Text(
              'Envoi de messages désactivé',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottom),
      duration: 160.ms,
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        padding: EdgeInsets.fromLTRB(
          DonySpacing.lg,
          DonySpacing.sm,
          DonySpacing.lg,
          DonySpacing.sm + MediaQuery.of(context).padding.bottom,
        ),
        // F1 : une seule pill — champ + bouton envoi à l'intérieur.
        child: Container(
          constraints: const BoxConstraints(maxHeight: 132),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(DonyRadius.xl),
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.only(left: DonySpacing.base, right: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  minLines: 1,
                  maxLength: ChatMessageRules.maxLength,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Votre message…',
                    hintStyle: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    return AnimatedScale(
                      scale: hasText ? 1.0 : 0.85,
                      duration: 150.ms,
                      curve: Curves.easeOutCubic,
                      child: Material(
                        color: hasText ? cs.primary : cs.outlineVariant,
                        shape: const CircleBorder(),
                        // Bouton à icône seule, et seul moyen d'envoyer un
                        // message depuis que le chat est le canal de contact
                        // unique. Sans nom accessible il était annoncé
                        // « bouton », sans plus.
                        child: Semantics(
                          button: true,
                          enabled: hasText && !isSending,
                          label: 'Envoyer le message',
                          container: true,
                          excludeSemantics: true,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: hasText && !isSending ? onSendText : null,
                            child: const SizedBox(
                              width: 38,
                              height: 38,
                              child: DonyIcon(
                                'send',
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
