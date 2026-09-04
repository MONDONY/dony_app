import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/corridor_alerts/data/models/corridor_alert_model.dart';
import 'package:flutter/material.dart';

enum CorridorAlertAction { edit, duplicate, pause, resume, delete }

/// Menu « ⋯ » d'une carte d'alerte. La feuille ne fait rien elle-même : elle
/// rend l'action choisie à l'écran liste, qui porte le bloc.
abstract final class CorridorAlertActionsSheet {
  static Future<CorridorAlertAction?> show(
    BuildContext context, {
    required CorridorAlertModel alert,
  }) {
    return DonyBottomSheet.show<CorridorAlertAction>(
      context,
      title: alert.corridorLabel,
      child: _Actions(active: alert.active),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    void choose(CorridorAlertAction a) => Navigator.of(context).pop(a);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyListTile(
          key: const Key('alert-action-edit'),
          iconAsset: 'square-pen',
          iconColor: cs.primary,
          iconBgColor: cs.primaryContainer,
          label: 'Modifier',
          subtitle: 'Corridor, dates et filtres',
          onTap: () => choose(CorridorAlertAction.edit),
        ),
        DonyListTile(
          key: const Key('alert-action-duplicate'),
          iconAsset: 'copy',
          iconColor: cs.primary,
          iconBgColor: cs.primaryContainer,
          label: 'Dupliquer',
          subtitle: 'Repartir de cette alerte pour en créer une autre',
          onTap: () => choose(CorridorAlertAction.duplicate),
        ),
        if (active)
          DonyListTile(
            key: const Key('alert-action-pause'),
            iconAsset: 'bell-off',
            iconColor: cs.onSurfaceVariant,
            iconBgColor: cs.surfaceContainerHighest,
            label: 'Mettre en pause',
            subtitle: 'Plus de notification, l\'alerte reste là',
            onTap: () => choose(CorridorAlertAction.pause),
          )
        else
          DonyListTile(
            key: const Key('alert-action-resume'),
            iconAsset: 'bell',
            iconColor: cs.primary,
            iconBgColor: cs.primaryContainer,
            label: 'Reprendre',
            subtitle: 'Les notifications repartent',
            onTap: () => choose(CorridorAlertAction.resume),
          ),
        DonyListTile(
          key: const Key('alert-action-delete'),
          iconAsset: 'trash-2',
          label: 'Supprimer',
          destructive: true,
          showDivider: false,
          onTap: () => choose(CorridorAlertAction.delete),
        ),
      ],
    );
  }
}
