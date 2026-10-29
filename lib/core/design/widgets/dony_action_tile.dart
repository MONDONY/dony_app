import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Tuile d'action du design system, façon « Outils » d'Activités : une icône
/// teintée, une pastille d'état facultative, un titre et une description.
///
/// Se pose dans un [DonyActionTileGrid] (deux tuiles par ligne). Un tap ouvre
/// l'écran ou la feuille que la tuile annonce.
class DonyActionTile extends StatelessWidget {
  const DonyActionTile({
    super.key,
    required this.iconName,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.showNotificationDot = false,
  });

  final String iconName;
  final String label;

  /// Couleur de la catégorie, bleu ou terracotta : teinte l'icône et son
  /// fond, sans aplat plein, pour ne pas concurrencer la grille d'activité.
  final Color color;
  final String? subtitle;

  /// Pastille d'état de l'outil, sur sa propre ligne sous l'icône. `null` pour
  /// les tuiles sans rien à remplir (Historique, Aide) ou tant que l'état est
  /// inconnu.
  final Widget? badge;

  /// Point ambre sur l'icône : l'outil a du nouveau depuis la dernière
  /// visite (aujourd'hui, seules les alertes s'en servent).
  final bool showNotificationDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // Un seul bouton pour le lecteur d'écran : titre, pastille et description
    // se lisent d'un trait, au lieu de trois éléments à parcourir.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: DonyCard(
          onTap: onTap,
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      DonyIconContainer(
                        iconAsset: iconName,
                        size: DonyIconContainerSize.sm,
                        backgroundColor: color.withValues(alpha: 0.12),
                        iconColor: color,
                        borderRadius: DonyRadius.iconBtn,
                      ),
                      if (showNotificationDot)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            key: const Key('tool-tile-dot'),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: DonyColors.amberDark,
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.surface, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              // La pastille prend sa propre ligne plutôt que la place restante à
              // droite de l'icône : sur un écran de 360 dp une tuile ne fait que
              // 154 px, il ne restait qu'une cinquantaine de pixels et « 4
              // destinataires » se coupait en « 4 desti… ».
              if (badge != null) ...[
                const SizedBox(height: DonySpacing.sm),
                badge!,
              ],
              const SizedBox(height: DonySpacing.xl),
              Text(
                label,
                style: tt.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: DonySpacing.xxs),
                Text(
                  subtitle!,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grille de [DonyActionTile] sur deux colonnes, lignes de hauteur égale.
///
/// `IntrinsicHeight` est nécessaire : dans un scroll, `stretch` seul réclame
/// une hauteur infinie et fait échouer le layout. Une dernière tuile en
/// nombre impair reste sur sa demi-largeur plutôt que de s'étirer, sinon elle
/// se lit comme une section à part.
class DonyActionTileGrid extends StatelessWidget {
  const DonyActionTileGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();

    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: DonySpacing.md));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: DonySpacing.md),
              Expanded(
                child: i + 1 < tiles.length
                    ? tiles[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}
