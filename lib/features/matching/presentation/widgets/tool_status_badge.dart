import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:flutter/material.dart';

/// Pastille d'état d'une tuile-outil du hub Activités (spec § 4.4) :
/// « ✓ 2 adresses » en success, ou « À configurer » en neutre.
class ToolStatusBadge extends StatelessWidget {
  const ToolStatusBadge({
    super.key,
    required this.ready,
    required this.label,
    required this.semanticsLabel,
  });

  final bool ready;
  final String label;

  /// Phrase complète pour le lecteur d'écran : la pastille seule ne dit pas
  /// de quel outil elle parle.
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fg = ready ? cs.success : cs.onSurfaceVariant;
    final bg = ready ? cs.successLight : cs.surfaceContainerHighest;

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
            if (ready) ...[
              DonyIcon('check', size: 12, color: fg),
              const SizedBox(width: DonySpacing.xs),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelMedium?.copyWith(
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
