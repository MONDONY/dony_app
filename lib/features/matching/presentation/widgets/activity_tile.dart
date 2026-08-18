import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Tuile d'activité du hub — icône, compteur, libellé.
///
/// Le compteur peut être en chargement ou indisponible, mais la tuile reste
/// toujours cliquable : c'est l'écran de destination qui gère son propre état
/// d'erreur, pas le hub.
class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.iconName,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.emptyHint,
    this.isLoading = false,
    this.hasError = false,
    this.showNotificationDot = false,
  });

  /// Nom du SVG dans `assets/icons/`, sans extension.
  final String iconName;

  /// Couleur de la catégorie : remplit la pastille d'icône (icône blanche
  /// dessus) et teinte le compteur, pour un code couleur lisible d'un coup.
  final Color iconColor;

  /// Valeur affichée. Ignorée si [isLoading] ou [hasError].
  final int value;
  final String label;

  /// Une ligne qui explique le domaine à un nouvel utilisateur
  /// (« Des colis à transporter pour vous »).
  final String? subtitle;

  /// Remplace le compteur quand il vaut zéro : un « 0 » nu ne dit rien à un
  /// novice, une invite (« Publiez un trajet ») fait de la tuile un tutoriel.
  final String? emptyHint;

  final VoidCallback onTap;
  final bool isLoading;
  final bool hasError;

  /// Affiche une pastille colorée au lieu du chevron — pour les domaines qui
  /// appellent une action de l'utilisateur.
  final bool showNotificationDot;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DonyCard(
      onTap: onTap,
      elevated: true,
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DonyIconContainer(
                iconAsset: iconName,
                size: DonyIconContainerSize.sm,
                backgroundColor: iconColor,
                iconColor: DonyColors.neutral0,
                borderRadius: DonyRadius.iconBtn,
              ),
              const SizedBox(height: DonySpacing.md),
              _ValueText(
                value: value,
                isLoading: isLoading,
                hasError: hasError,
                emptyHint: emptyHint,
                accentColor: iconColor,
              ),
              const SizedBox(height: DonySpacing.xxs),
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
          Positioned(
            top: 0,
            right: 0,
            child: showNotificationDot
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      // Rouge (attention), aligné sur le point de l'onglet
                      // Activités — plutôt que la couleur d'accent de la carte.
                      color: cs.error,
                      shape: BoxShape.circle,
                    ),
                  )
                : DonyIcon(
                    'chevron-right',
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ValueText extends StatelessWidget {
  const _ValueText({
    required this.value,
    required this.isLoading,
    required this.hasError,
    required this.emptyHint,
    required this.accentColor,
  });

  final int value;
  final bool isLoading;
  final bool hasError;
  final String? emptyHint;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (isLoading) {
      return const DonyShimmer(
        child: DonySkeletonBox(width: 32, height: 22, radius: DonyRadius.xs),
      );
    }

    if (!hasError && value == 0 && emptyHint != null) {
      return Text(
        emptyHint!,
        style: tt.bodySmall?.copyWith(
          color: accentColor,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      hasError ? '—' : '$value',
      style: tt.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: hasError ? cs.onSurfaceVariant : accentColor,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
