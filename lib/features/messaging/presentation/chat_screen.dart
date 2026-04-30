import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;
  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
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
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
            style: TextButton.styleFrom(foregroundColor: DonyColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _controller.clear();
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

  Future<void> _pickAndSendImage() async {
    final bloc = context.read<ChatBloc>();
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (xfile == null || !mounted) return;
    final bytes = await xfile.readAsBytes();
    bloc.add(
      ChatImageSendRequested(
        firestoreConversationId: widget.conversation.firestoreConversationId,
        conversationId: widget.conversation.id,
        senderFirebaseUid: _myUid,
        bytes: bytes,
        filename: xfile.name,
      ),
    );
  }

  Future<void> _sendLocation() async {
    final bloc = context.read<ChatBloc>();
    final messenger = ScaffoldMessenger.of(context);
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Permission de localisation refusée')),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      bloc.add(
        ChatLocationSendRequested(
          firestoreConversationId: widget.conversation.firestoreConversationId,
          conversationId: widget.conversation.id,
          senderFirebaseUid: _myUid,
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible de récupérer votre position')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final conversation = widget.conversation;
    final participant = conversation.otherParticipant;

    return Scaffold(
      backgroundColor: DonyColors.bgApp,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: cs.primary,
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            DonyAvatar(
              name: participant.name.isNotEmpty ? participant.name : '?',
              imageUrl: participant.avatarUrl,
              size: DonyAvatarSize.sm,
            ),
            const SizedBox(width: DonySpacing.sm),
            Expanded(
              child: Text(
                participant.name.isNotEmpty ? participant.name : 'Conversation',
                style: tt.titleLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _confirmAndDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 20, color: cs.error),
                    const SizedBox(width: DonySpacing.sm),
                    Text(
                      'Supprimer la conversation',
                      style: tt.bodyMedium?.copyWith(color: cs.error),
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
            current is ChatConversationDeleted ||
            current is ChatError,
        listener: (context, state) {
          if (state is ChatConversationDeleted) {
            // Remove from the list before popping so the tile vanishes immediately
            getIt<ConversationListBloc>().add(
              ConversationRemovedLocally(widget.conversation.id),
            );
            // Defer the pop one frame to avoid Hero animation assertion failures
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Conversation supprimée')),
              );
              if (context.canPop()) context.pop();
            });
          } else if (state is ChatError &&
              state.message == 'Impossible de supprimer la conversation') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, _) => Column(
        children: [
          // Sticky trip banner — clickable → /bids/:id
          if (conversation.tripLabel != null)
            _TripBanner(conversation: conversation, cs: cs, tt: tt),

          // Sticky bid status banner (informational, no actions)
          if (conversation.bidStatus != null)
            _BidStatusBanner(status: conversation.bidStatus!, cs: cs, tt: tt),

          // Message list
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state is ChatLoading || state is ChatInitial) {
                  return Center(child: CircularProgressIndicator(color: cs.primary));
                }

                if (state is ChatError) {
                  return DonyEmptyState(
                    type: DonyEmptyStateType.error,
                    icon: Icons.wifi_off_rounded,
                    title: 'Connexion interrompue',
                    description: state.message,
                    actionLabel: 'Réessayer',
                    onAction: () => context.read<ChatBloc>().add(
                          ChatSubscribeRequested(
                            widget.conversation.firestoreConversationId,
                          ),
                        ),
                  );
                }

                if (state is ChatLoaded) {
                  if (state.messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.35),
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
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      final isMe = message.senderId == _myUid;
                      final showDateSeparator = _showDateSeparator(
                        state.messages,
                        index,
                      );
                      return Column(
                        children: [
                          if (showDateSeparator)
                            _DateSeparator(date: message.sentAt, cs: cs, tt: tt),
                          _MessageBubble(message: message, isMe: isMe)
                              .animate()
                              .fadeIn(duration: 180.ms, curve: Curves.easeOutCubic),
                        ],
                      );
                    },
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),

          // Input bar
          _InputBar(
            controller: _controller,
            isSending: _isSending,
            onSendText: _sendText,
            onPickImage: _pickAndSendImage,
            onSendLocation: _sendLocation,
          ),
        ],
        ),
      ),
    );
  }

  bool _showDateSeparator(List<MessageModel> messages, int index) {
    if (index == messages.length - 1) return true;
    final current = messages[index].sentAt;
    final next = messages[index + 1].sentAt;
    return current.year != next.year ||
        current.month != next.month ||
        current.day != next.day;
  }
}

// ── Trip banner ────────────────────────────────────────────────────────────────

class _TripBanner extends StatelessWidget {
  final ConversationModel conversation;
  final ColorScheme cs;
  final TextTheme tt;

  const _TripBanner({
    required this.conversation,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.surface,
      child: InkWell(
        onTap: () => context.push('/bids/${conversation.bidId}'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DonySpacing.lg, 10, DonySpacing.sm, 10,
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
                    child: Icon(Icons.flight_rounded, size: 16, color: cs.primary),
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
                  Icon(
                    Icons.chevron_right_rounded,
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
    final config = switch (status) {
      'BID_ACCEPTED' => (
          Icons.check_circle_rounded,
          'Offre acceptée',
          DonyColors.success,
        ),
      'DELIVERY_CONFIRMED' => (
          Icons.local_shipping_rounded,
          'Livraison confirmée',
          DonyColors.success,
        ),
      'TRIP_CANCELLED' => (
          Icons.cancel_rounded,
          'Trajet annulé',
          cs.error,
        ),
      _ => null,
    };
    if (config == null) return const SizedBox.shrink();

    final (icon, label, color) = config;
    return Container(
      color: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(
        horizontal: DonySpacing.lg,
        vertical: DonySpacing.xs,
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
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

  const _DateSeparator({required this.date, required this.cs, required this.tt});

  String _label() {
    final now = DateTime.now();
    final isToday = now.year == date.year && now.month == date.month && now.day == date.day;
    final isYesterday = now.difference(date).inDays == 1;
    if (isToday) return 'Aujourd\'hui';
    if (isYesterday) return 'Hier';
    return DateFormat('d MMMM y', 'fr').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DonySpacing.md),
      child: Row(
        children: [
          Expanded(child: Divider(color: cs.outlineVariant, endIndent: DonySpacing.md)),
          Text(
            _label(),
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(child: Divider(color: cs.outlineVariant, indent: DonySpacing.md)),
        ],
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

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

    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.xs),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isMe ? cs.primary : cs.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(DonyRadius.card),
                        topRight: const Radius.circular(DonyRadius.card),
                        bottomLeft:
                            Radius.circular(isMe ? DonyRadius.card : DonyRadius.xs),
                        bottomRight:
                            Radius.circular(isMe ? DonyRadius.xs : DonyRadius.card),
                      ),
                      border: isMe ? null : Border.all(color: cs.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: DonyColors.shadow,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
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
                  const SizedBox(height: 3),
                  // Timestamp + read receipt
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.sentAt),
                        style: tt.bodySmall?.copyWith(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        Icon(
                          message.readAt != null
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 12,
                          color: message.readAt != null
                              ? cs.primary
                              : cs.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
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
        width: 220,
        height: 180,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 220,
          height: 180,
          color: DonyColors.neutral100,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 220,
          height: 180,
          color: DonyColors.neutral100,
          child: Icon(Icons.broken_image_outlined, color: DonyColors.textSubtle),
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
          Icon(
            Icons.location_on_rounded,
            size: 20,
            color: isMe ? cs.onPrimary : cs.error,
          ),
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
  const _DeletedContent({required this.isMe, required this.cs, required this.tt});

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
          Icon(
            Icons.block_rounded,
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

// ── Input bar ──────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSendText;
  final VoidCallback onPickImage;
  final VoidCallback onSendLocation;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSendText,
    required this.onPickImage,
    required this.onSendLocation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

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
          DonySpacing.xs,
          DonySpacing.sm,
          DonySpacing.sm,
          DonySpacing.sm + MediaQuery.of(context).padding.bottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: onPickImage,
              icon: Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
            IconButton(
              onPressed: onSendLocation,
              icon: Icon(Icons.location_on_outlined, color: cs.onSurfaceVariant),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
            const SizedBox(width: DonySpacing.xs),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: DonyColors.bgApp,
                  borderRadius: BorderRadius.circular(DonyRadius.xl),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Votre message…',
                    hintStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DonySpacing.md,
                      vertical: DonySpacing.sm,
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: DonySpacing.xs),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return AnimatedScale(
                  scale: hasText ? 1.0 : 0.85,
                  duration: 150.ms,
                  child: Material(
                    color: hasText ? cs.primary : cs.outlineVariant,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: hasText && !isSending ? onSendText : null,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
