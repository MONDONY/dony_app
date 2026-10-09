import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Rendu du compteur d'un segment.
enum DonySegmentCountStyle {
  /// Pastille rouge, seulement au-dessus de zéro : quelque chose attend
  /// l'utilisateur (discussions non lues).
  alert,

  /// Nombre discret, toujours affiché, zéro compris : taille de la liste.
  neutral,
}

/// Un segment de [DonySegmentedControl].
class DonySegment<T> {
  const DonySegment({
    required this.value,
    required this.label,
    this.count,
    this.countStyle = DonySegmentCountStyle.alert,
    this.key,
  });

  final T value;
  final String label;

  /// `null` : pas de compteur (liste pas encore chargée, par exemple).
  final int? count;
  final DonySegmentCountStyle countStyle;

  /// Clé posée sur la zone tappable du segment.
  final Key? key;
}

/// Bascule segmentée : une seule surface avec une capsule qui glisse sous le
/// segment choisi, plutôt que des pastilles séparées. Partagée par « Mes
/// colis » (En route / Publiés) et le mode « Suivre » de l'onglet Suivi
/// (Envois / Réceptions).
///
/// L'état de sélection vit chez l'appelant (cubit).
class DonySegmentedControl<T> extends StatelessWidget {
  const DonySegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelect,
  }) : assert(segments.length >= 2, 'Au moins deux segments');

  final List<DonySegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = segments.length;
    final index = segments
        .indexWhere((s) => s.value == selected)
        .clamp(0, n - 1);

    return Container(
      height: 46,
      padding: const EdgeInsets.all(DonySpacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        // Rayon concentrique : capsule (md) + marge intérieure (xs).
        borderRadius: BorderRadius.circular(DonyRadius.md + DonySpacing.xs),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segWidth = constraints.maxWidth / n;
          return Stack(
            children: [
              // Glisse, interruptible : un second tap repart de la position
              // courante.
              AnimatedAlign(
                duration: DonyDuration.base,
                curve: DonyCurve.easeOut,
                alignment: Alignment(-1 + 2 * index / (n - 1), 0),
                child: Container(
                  width: segWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(DonyRadius.md),
                    boxShadow: DonyShadows.card,
                  ),
                ),
              ),
              // Positioned.fill : sans ça la rangée de labels se cale en haut
              // à gauche du Stack et le texte n'est pas centré verticalement.
              Positioned.fill(
                // stretch : chaque segment est tappable sur toute sa
                // hauteur, pas seulement sur son libellé.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final s in segments)
                      Expanded(
                        child: _SegmentLabel(
                          key: s.key,
                          segment: s,
                          selected: s.value == selected,
                          onTap: () => onSelect(s.value),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentLabel<T> extends StatelessWidget {
  const _SegmentLabel({
    super.key,
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final DonySegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final count = segment.count;
    const tabular = [FontFeature.tabularFigures()];

    final Widget? counter = switch (segment.countStyle) {
      _ when count == null => null,
      DonySegmentCountStyle.alert when count <= 0 => null,
      DonySegmentCountStyle.alert => Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: tt.labelSmall?.copyWith(
            color: cs.onError,
            fontWeight: FontWeight.w800,
            height: 1,
            fontFeatures: tabular,
          ),
        ),
      ),
      DonySegmentCountStyle.neutral => Text(
        count > 99 ? '99+' : '$count',
        style: tt.labelLarge?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontFeatures: tabular,
        ),
      ),
    };

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                segment.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelLarge?.copyWith(
                  color: selected ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (counter != null) ...[
              const SizedBox(width: DonySpacing.xs),
              counter,
            ],
          ],
        ),
      ),
    );
  }
}
