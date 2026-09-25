import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/widgets/conversation_tile.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ArchivedConversationsScreen extends StatelessWidget {
  const ArchivedConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: DonyAppBar(title: l.archivedConversationsTitle),
      body: BlocBuilder<ConversationListBloc, ConversationListState>(
        builder: (context, state) {
          if (state is! ConversationListLoaded) {
            return ListView.builder(
              itemCount: 6,
              itemBuilder: (_, _) => const DonyConversationTileSkeleton(),
            );
          }

          final archived = state.archivedConversations;

          if (archived.isEmpty) {
            return DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: l.archivedConversationsEmptyTitle,
              description: l.archivedConversationsEmptyDescription,
            );
          }

          return ListView.builder(
            itemCount: archived.length,
            itemBuilder: (context, index) =>
                _ArchivedTile(conversation: archived[index]),
          );
        },
      ),
    );
  }
}

class _ArchivedTile extends StatelessWidget {
  final ConversationModel conversation;
  const _ArchivedTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    return Slidable(
      key: ValueKey(conversation.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.35,
        children: [
          SlidableAction(
            onPressed: (ctx) {
              ctx.read<ConversationListBloc>().add(
                ConversationUnarchiveRequested(conversation.id),
              );
              DonySnackbar.show(ctx, message: l.conversationUnarchivedSnackbar);
            },
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            icon: Icons.unarchive_outlined,
            label: l.conversationUnarchiveAction,
          ),
        ],
      ),
      child: ConversationTile(conversation: conversation),
    );
  }
}
