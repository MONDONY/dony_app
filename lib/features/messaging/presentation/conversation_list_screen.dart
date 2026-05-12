import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocBuilder<ConversationListBloc, ConversationListState>(
        builder: (context, state) {
          if (state is ConversationListLoading || state is ConversationListInitial) {
            return Center(child: CircularProgressIndicator(color: cs.primary));
          }

          if (state is ConversationListError) {
            return DonyEmptyState(
              type: DonyEmptyStateType.error,
              icon: Icons.wifi_off_rounded,
              title: 'Erreur de chargement',
              description: ErrorPresenter.resolve(state.error).message,
              actionLabel: 'Réessayer',
              onAction: () => context
                  .read<ConversationListBloc>()
                  .add(const ConversationsLoadRequested()),
            );
          }

          if (state is ConversationListLoaded) {
            if (state.conversations.isEmpty) {
              return const DonyEmptyState(
                mascotte: DonyMascotteType.assis,
                title: 'Aucun message',
                description: 'Vos conversations apparaîtront ici\naprès l\'acceptation d\'une offre.',
              );
            }

            return RefreshIndicator(
              color: cs.primary,
              onRefresh: () async => context
                  .read<ConversationListBloc>()
                  .add(const ConversationsLoadRequested()),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: state.conversations.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: cs.outlineVariant),
                itemBuilder: (context, index) {
                  final conv = state.conversations[index];
                  final tile = _ConversationTile(conversation: conv)
                      .animate()
                      .fadeIn(
                        delay: Duration(milliseconds: 50 * index),
                        duration: 260.ms,
                        curve: Curves.easeOutCubic,
                      )
                      .slideY(
                        begin: 0.03,
                        end: 0,
                        delay: Duration(milliseconds: 50 * index),
                        duration: 260.ms,
                        curve: Curves.easeOutCubic,
                      );

                  return Dismissible(
                    key: ValueKey(conv.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: DonySpacing.xl),
                      color: cs.error,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              color: cs.onError, size: 26),
                          const SizedBox(height: DonySpacing.xs),
                          Text(
                            'Supprimer',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: cs.onError,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (_) => getIt<ConversationListBloc>()
                        .add(ConversationDeleteRequested(conv.id)),
                    child: tile,
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

// ── Conversation tile ──────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final participant = conversation.otherParticipant;

    return Material(
      color: conversation.hasUnread
          ? cs.primaryContainer.withValues(alpha: 0.07)
          : cs.surface,
      child: InkWell(
        onTap: () => context.push(
          '/conversations/${conversation.id}',
          extra: conversation,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DonySpacing.lg,
            vertical: 14,
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
                  children: [
                    // Row 1: name + timestamp
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            participant.name.isNotEmpty
                                ? participant.name
                                : 'Utilisateur',
                            style: tt.bodyLarge?.copyWith(
                              fontWeight: conversation.hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.lastMessageAt != null) ...[
                          const SizedBox(width: DonySpacing.xs),
                          Text(
                            _formatTime(conversation.lastMessageAt!),
                            style: tt.labelSmall?.copyWith(
                              color: conversation.hasUnread
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                              fontWeight: conversation.hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Row 2: trip label (if available)
                    if (conversation.tripLabel != null) ...[
                      const SizedBox(height: 3),
                      _TripLabel(label: conversation.tripLabel!, cs: cs, tt: tt),
                    ],
                    const SizedBox(height: 3),
                    // Row 3: preview + unread badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _previewText(),
                            style: tt.bodySmall?.copyWith(
                              color: conversation.hasUnread
                                  ? cs.onSurface
                                  : cs.onSurfaceVariant,
                              fontWeight: conversation.hasUnread
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.unreadCount > 0) ...[
                          const SizedBox(width: DonySpacing.xs),
                          _UnreadBadge(count: conversation.unreadCount, cs: cs, tt: tt),
                        ],
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

  String _previewText() {
    final preview = conversation.lastMessagePreview;
    if (preview == null || preview.isEmpty) return 'Conversation démarrée';
    return preview;
  }

  String _formatTime(DateTime dt) {
    // Server timestamps arrive as UTC — display in the user's local zone.
    final local = dt.isUtc ? dt.toLocal() : dt;
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'maintenant';
    final isToday =
        now.year == local.year && now.month == local.month && now.day == local.day;
    if (isToday) return DateFormat('HH:mm').format(local);
    if (diff.inDays < 7) return DateFormat('EEE', 'fr').format(local);
    return DateFormat('d MMM', 'fr').format(local);
  }
}

// ── Trip label chip ────────────────────────────────────────────────────────────

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
        Icon(Icons.flight_rounded, size: 11, color: cs.primary),
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

// ── Unread count badge ─────────────────────────────────────────────────────────

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
