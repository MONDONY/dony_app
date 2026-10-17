import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_info_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Taille du badge GP Pro : pilule avec libellé ou pastille icône seule.
enum GpProBadgeSize { compact, full }

/// Badge « GP Pro » : voyageur régulier accordé par l'équipe Yadony.
///
/// Bleu info (`cs.info`) pour se distinguer du PRO payant (doré) et de
/// l'identité vérifiée (vert). Touché, il ouvre [GpProInfoSheet]. La zone
/// tactile fait au moins 44 pt sans grossir le visuel.
///
/// [surface] : écran d'origine (chaîne fermée de l'analytics : `trip_card`,
/// `traveler_sheet`, `chat`, `poster`…).
class GpProBadge extends StatelessWidget {
  const GpProBadge({
    required this.surface,
    super.key,
    this.size = GpProBadgeSize.full,
    this.interactive = true,
  });

  final GpProBadgeSize size;
  final String surface;
  final bool interactive;

  static const double _minTap = 44;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final compact = size == GpProBadgeSize.compact;

    final visual = compact
        ? Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.infoLight,
              shape: BoxShape.circle,
              border: Border.all(color: cs.info.withValues(alpha: 0.4)),
            ),
            child: DonyIcon('luggage', size: 10, color: cs.info),
          )
        : Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.sm,
              vertical: DonySpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: cs.infoLight,
              borderRadius: BorderRadius.circular(DonyRadius.full),
              border: Border.all(color: cs.info.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DonyIcon('luggage', size: 12, color: cs.info),
                const SizedBox(width: DonySpacing.xxs),
                Text(
                  l.gpProBadgeLabel,
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.info,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          );

    final hit = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: _minTap, minHeight: _minTap),
      child: Center(widthFactor: 1, heightFactor: 1, child: visual),
    );

    return Semantics(
      label: l.gpProBadgeSemantics,
      button: interactive,
      excludeSemantics: true,
      child: interactive
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => GpProInfoSheet.show(context, surface: surface),
              child: hit,
            )
          : hit,
    );
  }
}
