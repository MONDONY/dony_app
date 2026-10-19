import 'dart:io';

import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Photo obligatoire d'un colis dans une feuille du bas (refus du colis,
/// demande de supplément) : zone « Prendre une photo », puis miniature avec
/// « Reprendre la photo » et « Retirer la photo ».
///
/// Aucun `DonyButton` ici : dans une feuille, le seul `DonyButton` est
/// l'action principale de son `stickyBottom` (règle du CLAUDE.md racine).
class ParcelPhotoPicker extends StatelessWidget {
  const ParcelPhotoPicker({
    super.key,
    required this.title,
    required this.help,
    required this.photoPath,
    required this.busy,
    required this.onTake,
    required this.onRemove,
  });

  final String title;
  final String help;

  /// Photo locale, nulle tant qu'aucune n'est prise.
  final String? photoPath;

  /// Envoi en cours : les actions sont inactives.
  final bool busy;
  final VoidCallback onTake;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final path = photoPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: tt.titleSmall?.copyWith(color: cs.onSurface)),
        const SizedBox(height: DonySpacing.xs),
        Text(help, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: DonySpacing.md),
        if (path == null)
          _TakePhotoTile(
            label: l.parcelRefusalTakePhoto,
            onTap: busy ? null : onTake,
          )
        else
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(DonyRadius.md),
                child: Image.file(
                  File(path),
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 88,
                    height: 88,
                    color: cs.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: DonyIcon('camera', color: cs.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: busy ? null : onTake,
                    style: TextButton.styleFrom(
                      foregroundColor: cs.primary,
                      minimumSize: const Size(44, 44),
                    ),
                    icon: DonyIcon(
                      'camera',
                      color: busy ? cs.onSurfaceVariant : cs.primary,
                      size: 18,
                    ),
                    label: Text(l.parcelRefusalRetakePhoto),
                  ),
                ),
              ),
              IconButton(
                tooltip: l.parcelRefusalRemovePhoto,
                onPressed: busy ? null : onRemove,
                icon: DonyIcon('trash-2', color: cs.error, size: 20),
              ),
            ],
          ),
      ],
    );
  }
}

/// Zone tappable « Prendre une photo » : bordure, icône et libellé, couleur
/// unie.
class _TakePhotoTile extends StatelessWidget {
  const _TakePhotoTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final enabled = onTap != null;
    final color = enabled ? cs.primary : cs.onSurfaceVariant;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DonyRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DonyRadius.lg),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.base,
              vertical: DonySpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DonyRadius.lg),
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DonyIcon('camera', color: color, size: 20),
                const SizedBox(width: DonySpacing.sm),
                Text(label, style: tt.titleSmall?.copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
