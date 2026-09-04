import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Ton d'une [ToolStatusBadge].
enum ToolStatusTone {
  /// « ✓ 2 adresses » : l'outil est configuré.
  ready,

  /// « À configurer » : rien n'est encore rempli.
  todo,

  /// « ● 2 nouveaux » : quelque chose s'est passé depuis la dernière visite.
  /// Ambre, comme la tuile « Demandes reçues » : une opportunité, pas une
  /// erreur.
  news,
}

/// Pastille d'état d'une tuile-outil du hub Activités (spec § 4.4) :
/// « ✓ 2 adresses » en success, « À configurer » en neutre, ou « ● 2
/// nouveaux » en ambre pour un outil qui a du nouveau à montrer.
class ToolStatusBadge extends StatelessWidget {
  const ToolStatusBadge({
    super.key,
    required this.ready,
    required this.label,
    required this.semanticsLabel,
    this.tone,
  });

  final bool ready;
  final String label;

  /// Phrase complète pour le lecteur d'écran : la pastille seule ne dit pas
  /// de quel outil elle parle.
  final String semanticsLabel;

  /// Ton explicite ; déduit de [ready] sinon.
  final ToolStatusTone? tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final effectiveTone =
        tone ?? (ready ? ToolStatusTone.ready : ToolStatusTone.todo);
    final (bg, fg) = switch (effectiveTone) {
      ToolStatusTone.ready => (cs.successLight, cs.success),
      ToolStatusTone.todo => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      ToolStatusTone.news => (DonyColors.amberLight, DonyColors.amberDark),
    };

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Container(
        key: const Key('tool-status-badge'),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: DonySpacing.sm),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(DonyRadius.full),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (effectiveTone == ToolStatusTone.ready) ...[
              DonyIcon('check', size: 12, color: fg),
              const SizedBox(width: DonySpacing.xs),
            ] else if (effectiveTone == ToolStatusTone.news) ...[
              Container(
                key: const Key('tool-status-badge-dot'),
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              ),
              const SizedBox(width: DonySpacing.xs),
            ],
            // Flexible : sur une tuile étroite, le libellé se coupe plutôt
            // que de déborder de la pastille.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium?.copyWith(
                  color: fg,
                  // Le tracking de labelMedium (0,8) est calibré pour des
                  // chips en capitales ; ici le libellé est en casse normale
                  // et chaque dixième de pixel compte sur une tuile étroite.
                  letterSpacing: 0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
