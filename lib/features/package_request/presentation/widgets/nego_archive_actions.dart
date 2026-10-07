import 'dart:async';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/di/injection.dart';
import 'package:dony/core/error/error_presenter.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/matching/bloc/bid_negotiation_list_bloc.dart';
import 'package:dony/features/package_request/bloc/negotiation_list_bloc.dart';
import 'package:dony/features/package_request/data/models/nego_archive.dart';
import 'package:dony/features/package_request/data/models/nego_entry.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Gestes communs d'archivage / suppression d'une discussion de prix terminée
/// (FLUTTER-EJ), pour soi seulement. Repris des conversations de Messages :
/// mêmes libellés, même snackbar « Annuler » après archivage. Seule la
/// confirmation de suppression change de forme : une feuille, bouton
/// destructif en `stickyBottom`, conformément à la règle des bottom sheets.

/// Valeurs des entrées du menu ⋯ des écrans de détail.
const kNegoMenuArchive = 'archive';
const kNegoMenuUnarchive = 'unarchive';
const kNegoMenuDelete = 'delete';

/// Demande confirmation avant de supprimer une discussion de sa liste.
/// Renvoie `true` seulement sur le bouton destructif.
Future<bool> confirmDeleteNegotiation(BuildContext context) async {
  final l = context.l10n;
  final tt = Theme.of(context).textTheme;
  final cs = Theme.of(context).colorScheme;
  // La feuille vit sur le root navigator : on la referme avec son propre
  // contexte, jamais celui de l'appelant (qui peut être dans une branche).
  void close(BuildContext sheetContext, bool value) =>
      Navigator.of(sheetContext, rootNavigator: true).pop(value);

  final confirmed = await DonyBottomSheet.show<bool>(
    context,
    title: l.negotiationDeleteConfirmTitle,
    isDanger: true,
    stickyBottom: Builder(
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DonyButton(
            key: const Key('nego-delete-confirm'),
            label: l.commonDelete,
            variant: DonyButtonVariant.destructive,
            onPressed: () => close(sheetContext, true),
          ),
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            key: const Key('nego-delete-cancel'),
            label: l.commonCancel,
            variant: DonyButtonVariant.ghost,
            onPressed: () => close(sheetContext, false),
          ),
        ],
      ),
    ),
    child: Text(
      l.negotiationDeleteConfirmMessage,
      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
    ),
  );
  return confirmed ?? false;
}

/// Entrées du menu ⋯ d'un écran de détail, pour un fil terminé.
List<PopupMenuEntry<String>> negoArchiveMenuItems(
  BuildContext menuContext, {
  required bool archived,
}) {
  final l = menuContext.l10n;
  final cs = Theme.of(menuContext).colorScheme;
  return [
    PopupMenuItem(
      key: const Key('nego-menu-archive'),
      value: archived ? kNegoMenuUnarchive : kNegoMenuArchive,
      child: Text(
        archived ? l.negotiationUnarchiveAction : l.negotiationArchiveAction,
      ),
    ),
    PopupMenuItem(
      key: const Key('nego-menu-delete'),
      value: kNegoMenuDelete,
      child: Text(l.commonDelete, style: TextStyle(color: cs.error)),
    ),
  ];
}

/// Bouton ⋯ des écrans de détail d'un fil terminé : Archiver (ou
/// Désarchiver) et Supprimer. L'action part vers le BLoC de liste partagé,
/// qui retire la tuile aussitôt ; [NegoArchiveDetailListener] commente
/// l'issue et revient à la liste.
class NegoArchiveMenuButton extends StatelessWidget {
  const NegoArchiveMenuButton({
    super.key,
    required this.kind,
    required this.id,
    required this.archived,
  });

  final NegoEntryKind kind;

  /// Id du fil (demande) ou du bid (trajet).
  final String id;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      key: const Key('nego-archive-menu'),
      icon: DonyIcon('ellipsis', color: cs.onSurface, size: 22),
      onSelected: (value) => unawaited(
        runNegoArchiveFromDetail(
          context,
          negoArchiveActionOf(value),
          (action) => dispatchNegoArchive(kind, id, action, fromDetail: true),
        ),
      ),
      itemBuilder: (menuContext) =>
          negoArchiveMenuItems(menuContext, archived: archived),
    );
  }
}

/// Envoie l'action au BLoC de liste partagé (singleton GetIt) du bon type.
void dispatchNegoArchive(
  NegoEntryKind kind,
  String id,
  NegoArchiveAction action, {
  bool fromDetail = false,
}) {
  switch (kind) {
    case NegoEntryKind.request:
      if (getIt.isRegistered<NegotiationListBloc>()) {
        getIt<NegotiationListBloc>().add(
          NegotiationArchiveActionRequested(id, action, fromDetail: fromDetail),
        );
      }
    case NegoEntryKind.trip:
      if (getIt.isRegistered<BidNegotiationListBloc>()) {
        getIt<BidNegotiationListBloc>().add(
          BidNegotiationArchiveActionRequested(
            id,
            action,
            fromDetail: fromDetail,
          ),
        );
      }
  }
}

/// Écoute, sur un écran de détail, l'issue des actions qu'il a lancées.
class NegoArchiveDetailListener extends StatelessWidget {
  const NegoArchiveDetailListener({
    super.key,
    required this.kind,
    required this.id,
    required this.child,
  });

  final NegoEntryKind kind;
  final String id;
  final Widget child;

  bool _mine(NegoArchiveResult? before, NegoArchiveResult? after) =>
      after != null && after != before && after.fromDetail && after.id == id;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case NegoEntryKind.request:
        if (!getIt.isRegistered<NegotiationListBloc>()) return child;
        return BlocListener<NegotiationListBloc, NegotiationListState>(
          bloc: getIt<NegotiationListBloc>(),
          listenWhen: (a, b) => _mine(a.lastAction, b.lastAction),
          listener: (ctx, state) =>
              handleNegoArchiveDetailResult(ctx, state.lastAction!),
          child: child,
        );
      case NegoEntryKind.trip:
        if (!getIt.isRegistered<BidNegotiationListBloc>()) return child;
        return BlocListener<BidNegotiationListBloc, BidNegotiationListState>(
          bloc: getIt<BidNegotiationListBloc>(),
          listenWhen: (a, b) => _mine(a.lastAction, b.lastAction),
          listener: (ctx, state) =>
              handleNegoArchiveDetailResult(ctx, state.lastAction!),
          child: child,
        );
    }
  }
}

/// Traduit une valeur du menu ⋯ en action.
NegoArchiveAction negoArchiveActionOf(String value) => switch (value) {
  kNegoMenuUnarchive => NegoArchiveAction.unarchive,
  kNegoMenuDelete => NegoArchiveAction.delete,
  _ => NegoArchiveAction.archive,
};

/// Lance [action] depuis un écran de détail : la suppression passe d'abord par
/// la confirmation, l'archivage part directement.
Future<void> runNegoArchiveFromDetail(
  BuildContext context,
  NegoArchiveAction action,
  void Function(NegoArchiveAction action) dispatch,
) async {
  if (action == NegoArchiveAction.delete &&
      !await confirmDeleteNegotiation(context)) {
    return;
  }
  dispatch(action);
}

/// Commente un échec d'action. Un succès et un fil retiré (403/404 métier)
/// n'ont rien à dire : la tuile a déjà quitté la liste.
void showNegoArchiveFailure(BuildContext context, NegoArchiveResult result) {
  final l = context.l10n;
  switch (result.outcome) {
    case NegoArchiveOutcome.success:
    case NegoArchiveOutcome.gone:
      return;
    case NegoArchiveOutcome.stillOpen:
      DonySnackbar.show(
        context,
        message: l.negotiationStillOpenSnackbar,
        type: DonySnackbarType.warning,
      );
    case NegoArchiveOutcome.unsupported:
      DonySnackbar.show(
        context,
        message: l.negotiationArchiveUnavailableSnackbar,
        type: DonySnackbarType.warning,
      );
    case NegoArchiveOutcome.failed:
      unawaited(ErrorPresenter.show(context, result.error));
  }
}

/// Issue d'une action lancée depuis un écran de détail : succès → message
/// puis retour à la liste ; fil retiré → retour à la liste ; échec → message,
/// on reste sur le fil.
void handleNegoArchiveDetailResult(
  BuildContext context,
  NegoArchiveResult result,
) {
  final l = context.l10n;
  switch (result.outcome) {
    case NegoArchiveOutcome.success:
      DonySnackbar.show(
        context,
        message: switch (result.action) {
          NegoArchiveAction.archive => l.negotiationArchivedSnackbar,
          NegoArchiveAction.unarchive => l.negotiationUnarchivedSnackbar,
          NegoArchiveAction.delete => l.negotiationDeletedSnackbar,
        },
        type: DonySnackbarType.success,
      );
      _backToList(context);
    case NegoArchiveOutcome.gone:
      _backToList(context);
    case NegoArchiveOutcome.stillOpen:
    case NegoArchiveOutcome.unsupported:
    case NegoArchiveOutcome.failed:
      showNegoArchiveFailure(context, result);
  }
}

void _backToList(BuildContext context) {
  if (context.canPop()) {
    context.pop(true);
  } else {
    context.go('/negotiations');
  }
}
