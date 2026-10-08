import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Ligne « Archivées » en tête d'une liste, à la manière de WhatsApp : elle
/// ouvre les archives et n'existe que s'il y en a ([count] > 0, à la charge de
/// l'appelant). Le compteur est en chiffres tabulaires pour ne pas faire
/// bouger la ligne quand il change.
class DonyArchivedRow extends StatelessWidget {
  const DonyArchivedRow({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.count,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(
      horizontal: DonySpacing.lg,
      vertical: DonySpacing.md,
    ),
    this.leadingWidth = 44,
  });

  /// Libellé court (« Archivées »).
  final String label;

  /// Annonce du lecteur d'écran (« Archivées (3) »).
  final String semanticLabel;
  final int count;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;

  /// Largeur de la colonne d'icône, alignée sur celle des avatars de la liste.
  final double leadingWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              SizedBox(
                width: leadingWidth,
                child: DonyIcon(
                  'archive',
                  size: 22,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$count',
                style: tt.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: DonySpacing.xs),
              DonyIcon('chevron-right', size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
