import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/widgets/conversation_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ArchivedConversationsScreen extends StatelessWidget {
  const ArchivedConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DonyAppBar(title: 'Archives'),
      body: BlocBuilder<ConversationListBloc, ConversationListState>(
        builder: (context, state) {
          if (state is! ConversationListLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final archived = state.archivedConversations;

          if (archived.isEmpty) {
            return const DonyEmptyState(
              mascotte: DonyMascotteType.assis,
              title: 'Aucune archive',
              description:
                  'Les conversations que vous archivez apparaîtront ici.',
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
              DonySnackbar.show(ctx, message: 'Conversation désarchivée');
            },
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            icon: Icons.unarchive_outlined,
            label: 'Désarchiver',
          ),
        ],
      ),
      child: ConversationTile(conversation: conversation),
    );
  }
}
