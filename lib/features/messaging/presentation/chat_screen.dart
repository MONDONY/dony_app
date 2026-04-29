import 'package:cached_network_image/cached_network_image.dart';
import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/messaging/bloc/chat/chat_bloc.dart';
import 'package:dony/features/messaging/bloc/chat/chat_event.dart';
import 'package:dony/features/messaging/bloc/chat/chat_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/data/models/message_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (xfile == null || !mounted) return;
    final bytes = await xfile.readAsBytes();
    context.read<ChatBloc>().add(
          ChatImageSendRequested(
            firestoreConversationId: widget.conversation.firestoreConversationId,
            conversationId: widget.conversation.id,
            senderFirebaseUid: _myUid,
            bytes: bytes,
            filename: xfile.name,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final participant = widget.conversation.otherParticipant;

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
          onPressed: () => Navigator.of(context).pop(),
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outline),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state is ChatLoading || state is ChatInitial) {
                  return Center(
                    child: CircularProgressIndicator(color: cs.primary),
                  );
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
                  final messages = state.messages;

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
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
                      return _MessageBubble(
                        message: message,
                        isMe: isMe,
                      ).animate().fadeIn(
                            duration: 200.ms,
                            curve: Curves.easeOutCubic,
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
            onSendText: _sendText,
            onPickImage: _pickAndSendImage,
          ),
        ],
      ),
    );
  }
}

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
              message.isDeleted
                  ? 'Message supprimé'
                  : (message.body ?? ''),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                        bottomLeft: Radius.circular(isMe ? DonyRadius.card : DonyRadius.xs),
                        bottomRight: Radius.circular(isMe ? DonyRadius.xs : DonyRadius.card),
                      ),
                      border: isMe
                          ? null
                          : Border.all(color: cs.outline, width: 1),
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
                            : _TextContent(
                                body: message.body ?? '',
                                isMe: isMe,
                                cs: cs,
                                tt: tt,
                              ),
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    DateFormat('HH:mm').format(message.sentAt),
                    style: tt.bodySmall?.copyWith(
                      fontSize: 10,
                      color: cs.onSurfaceVariant,
                    ),
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
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 220,
          height: 180,
          color: DonyColors.neutral100,
          child: Icon(
            Icons.broken_image_outlined,
            color: DonyColors.textSubtle,
          ),
        ),
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

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSendText;
  final VoidCallback onPickImage;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSendText,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottom),
      duration: 160.ms,
      curve: Curves.easeOutCubic,
      child: Container(
        color: cs.surface,
        padding: EdgeInsets.fromLTRB(
          DonySpacing.lg,
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
            const SizedBox(width: DonySpacing.xs),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: DonyColors.bgApp,
                  borderRadius: BorderRadius.circular(DonyRadius.xl),
                  border: Border.all(color: cs.outline),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface,
                      ),
                  decoration: InputDecoration(
                    hintText: 'Votre message…',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
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
                    color: hasText ? cs.primary : cs.outline,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: hasText && !isSending ? onSendText : null,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
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
