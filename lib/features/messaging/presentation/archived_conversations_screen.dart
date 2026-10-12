import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_bloc.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_event.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/bloc/conversation_selection/conversation_selection_cubit.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/features/messaging/presentation/widgets/conversation_selection_bar.dart';
import 'package:dony/features/messaging/presentation/widgets/conversation_tile.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ArchivedConversationsScreen extends StatelessWidget {
  const ArchivedConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Même mode sélection que la liste (FLUTTER-M4), avec « Désarchiver » en
    // lot.
    return BlocProvider<ConversationSelectionCubit>(
      create: (_) => getIt<ConversationSelectionCubit>(
        param1: ConversationSelectionSource.archives,
      ),
      child: const _ArchivedConversationsView(),
    );
  }
}

class _ArchivedConversationsView extends StatelessWidget {
  const _ArchivedConversationsView();

  void _unarchiveSelection(BuildContext context) {
    final selection = context.read<ConversationSelectionCubit>();
    final ids = selection.state.selectedIds.toList();
    if (ids.isEmpty) return;
    context.read<ConversationListBloc>().add(
      ConversationsBatchUnarchiveRequested(ids),
    );
    selection.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final selection = context.watch<ConversationSelectionCubit>().state;
    return PopScope(
      canPop: !selection.isActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.read<ConversationSelectionCubit>().clear();
      },
      child: Scaffold(
        appBar: selection.isActive
            ? null
            : DonyAppBar(title: l.archivedConversationsTitle),
        body: SafeArea(
          top: selection.isActive,
          bottom: false,
          child: BlocConsumer<ConversationListBloc, ConversationListState>(
            listenWhen: (previous, current) =>
                current is ConversationListLoaded,
            listener: (context, state) {
              state as ConversationListLoaded;
              context.read<ConversationSelectionCubit>().retainOnly({
                for (final c in state.archivedConversations) c.id,
              });
              final batch = state.batchFeedback;
              if (batch != null &&
                  batch.action == ConversationBatchAction.unarchive &&
                  !batch.isUndo) {
                showBatchFeedback(context, batch);
              }
            },
            builder: (context, state) {
              if (state is! ConversationListLoaded) {
                return ListView.builder(
                  itemCount: 6,
                  itemBuilder: (_, _) => const DonyConversationTileSkeleton(),
                );
              }

              final archived = state.archivedConversations;

              return Column(
                children: [
                  if (selection.isActive)
                    ConversationSelectionBar(
                      key: const Key('conversation-selection-bar'),
                      count: selection.count,
                      onClose: context.read<ConversationSelectionCubit>().clear,
                      onSelectFinished: () => selectFinished(context, archived),
                      actions: [
                        ConversationSelectionAction(
                          key: const Key('conversation-batch-unarchive'),
                          icon: Icons.unarchive_outlined,
                          label: l.conversationUnarchiveAction,
                          onPressed: () => _unarchiveSelection(context),
                        ),
                      ],
                    ),
                  Expanded(
                    child: archived.isEmpty
                        ? DonyEmptyState(
                            mascotte: DonyMascotteType.assis,
                            title: l.archivedConversationsEmptyTitle,
                            description:
                                l.archivedConversationsEmptyDescription,
                          )
                        : ListView.builder(
                            itemCount: archived.length,
                            itemBuilder: (context, index) =>
                                _ArchivedTile(conversation: archived[index]),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
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
    final id = conversation.id;
    final selected = context.select<ConversationSelectionCubit, bool?>(
      (c) => c.state.isActive ? c.state.isSelected(id) : null,
    );
    final selection = context.read<ConversationSelectionCubit>();

    return Slidable(
      key: ValueKey(conversation.id),
      enabled: selected == null,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.35,
        children: [
          DonySwipeAction(
            key: const Key('conversation-swipe-unarchive'),
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
      child: ConversationTile(
        conversation: conversation,
        selected: selected,
        onTap: selected == null ? null : () => selection.toggle(id),
        onLongPress: () {
          HapticFeedback.selectionClick();
          selection.startWith(id);
        },
      ),
    );
  }
}
