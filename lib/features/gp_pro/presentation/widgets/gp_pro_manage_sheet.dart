import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Ce que le GP Pro veut faire de son statut.
enum GpProManageChoice {
  /// Rouvrir le formulaire GP Pro (une nouvelle validation suivra).
  edit,

  /// Redevenir particulier en un tap.
  resign,
}

/// Feuille « Votre statut GP Pro » : deux actions, « Modifier mes
/// informations » (rouvre le formulaire) et « Redevenir particulier ».
///
/// Les deux boutons vivent dans le `stickyBottom` et se lisent sur une ligne.
/// La feuille ne porte aucun état : elle rend le choix, l'appelant agit.
abstract final class GpProManageSheet {
  /// Rend le choix, ou `null` si la feuille est fermée d'un geste.
  static Future<GpProManageChoice?> show(BuildContext context) {
    final l = context.l10n;
    return DonyBottomSheet.show<GpProManageChoice>(
      context,
      analyticsName: 'gp-pro/manage',
      title: l.gpProManageTitle,
      stickyBottom: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyButton(
              key: const Key('gp-pro-manage-edit'),
              label: sheetContext.l10n.gpProManageEdit,
              onPressed: () =>
                  Navigator.of(sheetContext).pop(GpProManageChoice.edit),
            ),
            const SizedBox(height: DonySpacing.xs),
            DonyButton(
              key: const Key('gp-pro-manage-resign'),
              label: sheetContext.l10n.gpProManageResign,
              variant: DonyButtonVariant.ghost,
              onPressed: () =>
                  Navigator.of(sheetContext).pop(GpProManageChoice.resign),
            ),
          ],
        ),
      ),
      child: Builder(
        builder: (sheetContext) => Text(
          sheetContext.l10n.gpProManageHint,
          style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
            color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
