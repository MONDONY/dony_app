import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ConversationListBloc>().add(const ConversationsLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: BlocBuilder<ConversationListBloc, ConversationListState>(
        builder: (context, state) {
          if (state is ConversationListLoading || state is ConversationListInitial) {
            return Center(
              child: CircularProgressIndicator(color: cs.primary),
            );
          }

          if (state is ConversationListError) {
            return DonyEmptyState(
              type: DonyEmptyStateType.error,
              icon: Icons.wifi_off_rounded,
              title: 'Erreur de chargement',
              description: state.message,
              actionLabel: 'Réessayer',
              onAction: () => context
                  .read<ConversationListBloc>()
                  .add(const ConversationsLoadRequested()),
            );
          }

          if (state is ConversationListLoaded) {
            if (state.conversations.isEmpty) {
              return const DonyEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Aucun message',
                description:
                    'Vos conversations apparaîtront ici\naprès l\'acceptation d\'une offre.',
              );
            }

            return RefreshIndicator(
              color: cs.primary,
              onRefresh: () async => context
                  .read<ConversationListBloc>()
                  .add(const ConversationsLoadRequested()),
              child: ListView.separated(
                padding: const EdgeInsets.only(top: DonySpacing.sm),
                itemCount: state.conversations.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: DonySpacing.lg + DonySpacing.icon + DonySpacing.md,
                  endIndent: DonySpacing.lg,
                  color: cs.outline,
                ),
                itemBuilder: (context, index) {
                  return _ConversationTile(
                    conversation: state.conversations[index],
                  )
                      .animate()
                      .fadeIn(
                        delay: Duration(milliseconds: 60 * index),
                        duration: 280.ms,
                        curve: Curves.easeOutCubic,
                      )
                      .slideY(
                        begin: 0.04,
                        end: 0,
                        delay: Duration(milliseconds: 60 * index),
                        duration: 280.ms,
                        curve: Curves.easeOutCubic,
                      );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final participant = conversation.otherParticipant;

    return InkWell(
      onTap: () => context.push(
        '/conversations/${conversation.id}',
        extra: conversation,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DonySpacing.lg,
          vertical: DonySpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DonyAvatar(
              name: participant.name.isNotEmpty ? participant.name : '?',
              imageUrl: participant.avatarUrl,
              size: DonyAvatarSize.md,
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          participant.name.isNotEmpty
                              ? participant.name
                              : 'Utilisateur',
                          style: tt.titleLarge?.copyWith(
                            fontWeight: conversation.hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: DonySpacing.xs),
                      if (conversation.lastMessageAt != null)
                        Text(
                          _formatTime(conversation.lastMessageAt!),
                          style: tt.bodySmall?.copyWith(
                            color: conversation.hasUnread
                                ? cs.primary
                                : cs.onSurfaceVariant,
                            fontWeight: conversation.hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: DonySpacing.xxs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessagePreview ?? 'Conversation démarrée',
                          style: tt.bodySmall?.copyWith(
                            color: conversation.hasUnread
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                            fontWeight: conversation.hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.hasUnread) ...[
                        const SizedBox(width: DonySpacing.xs),
                        _UnreadDot(color: cs.primary),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'maintenant';
    if (diff.inHours < 1) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return DateFormat('EEE', 'fr').format(dt);
    return DateFormat('dd/MM', 'fr').format(dt);
  }
}

class _UnreadDot extends StatelessWidget {
  final Color color;
  const _UnreadDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
