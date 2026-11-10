import 'package:dony/core/design/design_system.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Feuille « Votre statut GP Pro » d'un GP Pro actif : une seule action,
/// « Redevenir particulier ». Le back refuse une nouvelle demande à un GP Pro
/// actif (409 `gp-pro-already-active`) : il n'y a pas de « Modifier mes
/// informations ». Le bouton vit dans le `stickyBottom` et se lit sur une ligne.
///
/// La feuille ne porte aucun état : elle rend le choix, l'appelant agit.
abstract final class GpProManageSheet {
  /// Rend `true` si le voyageur veut redevenir particulier, `null` si la feuille
  /// est fermée d'un geste.
  static Future<bool?> show(BuildContext context) {
    final l = context.l10n;
    return DonyBottomSheet.show<bool>(
      context,
      analyticsName: 'gp-pro/manage',
      title: l.gpProManageTitle,
      stickyBottom: Builder(
        builder: (sheetContext) => DonyButton(
          key: const Key('gp-pro-manage-resign'),
          label: sheetContext.l10n.gpProManageResign,
          variant: DonyButtonVariant.destructiveGhost,
          onPressed: () => Navigator.of(sheetContext).pop(true),
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
