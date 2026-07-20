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
    required this.iconBackground,
    required this.value,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.hasError = false,
    this.showNotificationDot = false,
  });

  /// Nom du SVG dans `assets/icons/`, sans extension.
  final String iconName;
  final Color iconColor;
  final Color iconBackground;

  /// Valeur affichée. Ignorée si [isLoading] ou [hasError].
  final int value;
  final String label;
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
      padding: const EdgeInsets.all(DonySpacing.base),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: DonySpacing.icon - 8,
                height: DonySpacing.icon - 8,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(DonyRadius.iconBtn),
                ),
                child: Center(
                  child: DonyIcon(iconName, size: 16, color: iconColor),
                ),
              ),
              const SizedBox(height: DonySpacing.md),
              _ValueText(
                value: value,
                isLoading: isLoading,
                hasError: hasError,
              ),
              const SizedBox(height: DonySpacing.xxs),
              Text(
                label,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
                      color: iconColor,
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
  });

  final int value;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (isLoading) {
      return Container(
        width: 32,
        height: 22,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DonyRadius.xs),
        ),
      );
    }

    return Text(
      hasError ? '—' : '$value',
      style: tt.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
