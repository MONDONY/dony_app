import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Carte de statistique du hub — largeur fixe, pensée pour une rangée
/// horizontale défilante.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.iconName,
    required this.label,
    required this.value,
    this.isLoading = false,
  });

  static const double width = 132;

  final String iconName;
  final String label;

  /// Valeur déjà formatée (`0 €`, `12,5 kg`, `2 publiés`).
  final String value;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      child: DonyCard(
        padding: const EdgeInsets.all(DonySpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DonyIcon(iconName, size: 20, color: cs.onSurface),
            const SizedBox(height: DonySpacing.lg),
            Text(
              label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: DonySpacing.xxs),
            if (isLoading)
              Container(
                width: 48,
                height: 18,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(DonyRadius.xs),
                ),
              )
            else
              Text(
                value,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
