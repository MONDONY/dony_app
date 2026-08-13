import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  const ConversationTile({super.key, required this.conversation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final participant = conversation.otherParticipant;
    final unread = conversation.hasUnread;

    return Material(
      // Surlignage non-lu : teinte primary légère par-dessus la surface,
      // lisible en clair comme en sombre (fini le bleu clair figé).
      color: unread
          ? Color.alphaBlend(cs.primary.withValues(alpha: 0.06), cs.surface)
          : cs.surface,
      child: InkWell(
        onTap: () async {
          // Le chat a son propre ChatBloc (registerFactory) : la liste ne sait
          // pas qu'un message a été envoyé/lu tant qu'on ne recharge pas au
          // retour (règle CLAUDE.md « Rafraîchissement après navigation »).
          final bloc = context.read<ConversationListBloc>();
          await context.push(
            '/conversations/${conversation.id}',
            extra: conversation,
          );
          bloc.add(const ConversationsLoadRequested());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.lg,
            vertical: 12,
          ),
          child: Row(
            children: [
              DonyAvatar(
                name: participant.name.isNotEmpty ? participant.name : '?',
                imageUrl: participant.avatarUrl,
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            participant.name.isNotEmpty
                                ? participant.name
                                : 'Utilisateur',
                            style: tt.titleLarge?.copyWith(
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.lastMessageAt != null) ...[
                          const SizedBox(width: DonySpacing.xs),
                          Text(
                            formatConversationTime(conversation.lastMessageAt!),
                            style: tt.labelSmall?.copyWith(
                              color: unread ? cs.primary : cs.onSurfaceVariant,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (conversation.tripLabel != null) ...[
                      const SizedBox(height: 3),
                      _TripLabel(
                        label: conversation.tripLabel!,
                        cs: cs,
                        tt: tt,
                      ),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _previewText(conversation),
                            style: tt.bodySmall?.copyWith(
                              color: unread
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                              fontWeight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: DonySpacing.xs),
                        if (unread && conversation.unreadCount > 0)
                          _UnreadBadge(
                            count: conversation.unreadCount,
                            cs: cs,
                            tt: tt,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _previewText(ConversationModel c) {
  final preview = c.lastMessagePreview;
  if (preview == null || preview.isEmpty) {
    return 'Conversation démarrée';
  }
  return preview;
}

String formatConversationTime(DateTime dt) {
  final local = dt.isUtc ? dt.toLocal() : dt;
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) {
    return 'maintenant';
  }
  final isToday =
      now.year == local.year &&
      now.month == local.month &&
      now.day == local.day;
  if (isToday) {
    return DateFormat('HH:mm').format(local);
  }
  if (diff.inDays < 7) {
    return DateFormat('EEE', 'fr').format(local);
  }
  return DateFormat('d MMM', 'fr').format(local);
}

class _TripLabel extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  final TextTheme tt;
  const _TripLabel({required this.label, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyIcon('plane', size: 11, color: cs.primary),
        const SizedBox(width: DonySpacing.xs),
        Flexible(
          child: Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  final ColorScheme cs;
  final TextTheme tt;
  const _UnreadBadge({required this.count, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: tt.labelSmall?.copyWith(
          color: cs.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
