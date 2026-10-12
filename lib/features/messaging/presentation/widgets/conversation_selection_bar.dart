import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/features/messaging/bloc/conversation_list/conversation_list_state.dart';
import 'package:dony/features/messaging/bloc/conversation_selection/conversation_selection_cubit.dart';
import 'package:dony/features/messaging/data/models/conversation_model.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Action de la barre de sélection (Archiver, Supprimer, Désarchiver).
class ConversationSelectionAction {
  final Key? key;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  const ConversationSelectionAction({
    this.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });
}

/// En-tête du mode sélection (FLUTTER-M4), commun à la liste des
/// conversations et aux archives : fermeture, compteur « N sélectionnées »,
/// raccourci « Sélectionner les terminées » et actions groupées.
class ConversationSelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onClose;
  final VoidCallback? onSelectFinished;
  final List<ConversationSelectionAction> actions;

  const ConversationSelectionBar({
    super.key,
    required this.count,
    required this.onClose,
    required this.actions,
    this.onSelectFinished,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;

    return Container(
      color: cs.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.xs,
              DonySpacing.sm,
              DonySpacing.base,
              0,
            ),
            child: Row(
              children: [
                IconButton(
                  key: const Key('conversation-selection-close'),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: l.conversationSelectionClose,
                  onPressed: onClose,
                ),
                const SizedBox(width: DonySpacing.xs),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l.conversationSelectionCount(count),
                      key: const Key('conversation-selection-count'),
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              DonySpacing.base,
              DonySpacing.xs,
              DonySpacing.base,
              DonySpacing.sm,
            ),
            child: Row(
              children: [
                if (onSelectFinished != null)
                  TextButton.icon(
                    key: const Key('conversation-select-finished'),
                    onPressed: onSelectFinished,
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: Text(l.conversationSelectFinished),
                  ),
                for (final a in actions) ...[
                  const SizedBox(width: DonySpacing.xs),
                  TextButton.icon(
                    key: a.key,
                    onPressed: count == 0 ? null : a.onPressed,
                    style: a.destructive
                        ? TextButton.styleFrom(foregroundColor: cs.error)
                        : null,
                    icon: Icon(a.icon, size: 18),
                    label: Text(a.label),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
        ],
      ),
    );
  }
}

/// Raccourci « Sélectionner les terminées » : coche les fils de colis livrés
/// ou annulés parmi [displayed]. L'utilisateur garde la main : rien n'est
/// archivé ni supprimé sans son geste.
void selectFinished(BuildContext context, List<ConversationModel> displayed) {
  final finished = [
    for (final c in displayed)
      if (c.isFinished) c.id,
  ];
  if (finished.isEmpty) {
    DonySnackbar.show(
      context,
      message: context.l10n.conversationSelectFinishedNone,
    );
    return;
  }
  context.read<ConversationSelectionCubit>().addAll(finished);
}

/// Dialogue de confirmation d'une suppression groupée, avec le nombre de
/// conversations visées.
Future<bool> confirmBatchDelete(BuildContext context, int count) async {
  final l = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    // Le dialog vit sur le navigateur racine : les pop passent par son
    // propre contexte, sinon ils dépileraient la branche de l'onglet.
    builder: (dialogCtx) => AlertDialog(
      title: Text(l.conversationBatchDeleteConfirmTitle(count)),
      content: Text(l.conversationDeleteConfirmMessage),
      actions: [
        TextButton(
          key: const Key('conversation-batch-delete-cancel'),
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: Text(l.commonCancel),
        ),
        TextButton(
          key: const Key('conversation-batch-delete-confirm'),
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogCtx).colorScheme.error,
          ),
          child: Text(l.commonDelete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Snackbar du retour d'une action groupée : confirmation (avec « Annuler »
/// pour un archivage), échec partiel, ou erreur globale.
void showBatchFeedback(
  BuildContext context,
  ConversationBatchFeedback feedback, {
  void Function(List<String> ids)? onUndoArchive,
}) {
  if (feedback.error != null) {
    ErrorPresenter.show(context, feedback.error);
    return;
  }
  final l = context.l10n;
  final done = feedback.succeededIds.length;
  final parts = <String>[
    if (done > 0 && !feedback.isUndo)
      switch (feedback.action) {
        ConversationBatchAction.archive => l.conversationBatchArchivedSnackbar(
          done,
        ),
        ConversationBatchAction.unarchive =>
          l.conversationBatchUnarchivedSnackbar(done),
        ConversationBatchAction.delete => l.conversationBatchDeletedSnackbar(
          done,
        ),
      },
    if (feedback.failedCount > 0)
      l.conversationBatchPartialFailure(feedback.failedCount),
  ];
  if (parts.isEmpty) return;
  final canUndo =
      feedback.action == ConversationBatchAction.archive &&
      done > 0 &&
      onUndoArchive != null;
  DonySnackbar.show(
    context,
    message: parts.join(' '),
    type: feedback.failedCount > 0
        ? DonySnackbarType.warning
        : DonySnackbarType.info,
    actionLabel: canUndo ? l.commonCancel : null,
    onAction: canUndo ? () => onUndoArchive(feedback.succeededIds) : null,
  );
}
