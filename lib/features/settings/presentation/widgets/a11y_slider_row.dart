import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/settings/bloc/accessibility_bloc.dart';
import 'package:flutter/material.dart';

/// Ligne de réglage de la taille du texte.
///
/// Remplace le `SegmentedButton` d'origine : quatre segments plus une icône de
/// coche ne tenaient pas dans la largeur, ce qui coupait « Normale » en trois
/// lignes. Un curseur ne peut pas déborder, quelle que soit la taille de texte
/// appliquée, et offre 24 valeurs au lieu de 4.
class A11ySliderRow extends StatelessWidget {
  const A11ySliderRow({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final double value;

  /// Faux quand la taille suit le système : le curseur est alors inerte et
  /// grisé, plutôt que masqué, pour que le réglage reste lisible.
  final bool enabled;

  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final percent = '${(value * 100).round()} %';

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DonySpacing.base,
          DonySpacing.md,
          DonySpacing.base,
          DonySpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Taille du texte',
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Text(
                  percent,
                  style: tt.titleMedium?.copyWith(color: cs.primary),
                ),
              ],
            ),
            Semantics(
              label: 'Taille du texte',
              value: percent,
              child: Slider(
                value: value,
                min: kA11yMinTextScale,
                max: kA11yMaxTextScale,
                // Pas de 5 % : assez fin pour ajuster, assez grossier pour
                // être atteignable au doigt.
                divisions: ((kA11yMaxTextScale - kA11yMinTextScale) / 0.05)
                    .round(),
                label: percent,
                onChanged: enabled ? onChanged : null,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('85 %', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                Text('200 %', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
