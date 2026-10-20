import 'package:dony/core/design/tokens/spacing_tokens.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/gp_pro/presentation/widgets/gp_pro_info_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Taille du badge GP Pro : pilule avec libellé ou pastille icône seule.
enum GpProBadgeSize { compact, full }

/// Badge « GP Pro » : voyageur régulier accordé par l'équipe Yadony.
///
/// Argent, comme la coche GP Pro de l'avatar : le PRO payant est doré, le
/// compte vérifié seul bleu. Touché, il ouvre [GpProInfoSheet]. La zone
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

  /// Argent : fond clair et texte gris-bleu foncé (≥ 7:1), identiques en thème
  /// clair et sombre pour rester lisibles sur le bandeau bleu du profil.
  static const Color _silverBg = Color(0xFFE6EAF0);
  static const Color _silverFg = Color(0xFF3A4556);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final compact = size == GpProBadgeSize.compact;

    final visual = compact
        ? Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _silverBg,
              shape: BoxShape.circle,
              border: Border.all(color: _silverFg.withValues(alpha: 0.4)),
            ),
            child: const DonyIcon('luggage', size: 10, color: _silverFg),
          )
        : Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.sm,
              vertical: DonySpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: _silverBg,
              borderRadius: BorderRadius.circular(DonyRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DonyIcon('luggage', size: 12, color: _silverFg),
                const SizedBox(width: DonySpacing.xxs),
                Text(
                  l.gpProBadgeLabel,
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _silverFg,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          );

    void open() => GpProInfoSheet.show(context, surface: surface);

    final semantic = Semantics(
      label: l.gpProBadgeSemantics,
      button: interactive,
      onTap: interactive ? open : null,
      excludeSemantics: true,
      child: interactive
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: open,
              child: visual,
            )
          : visual,
    );
    // Doit envelopper Semantics : un parent de taille stricte filtrerait les
    // touchers hors cadre avant qu'ils n'arrivent à la zone élargie.
    return interactive
        ? _ExpandedHitArea(minSize: _minTap, child: semantic)
        : semantic;
  }
}

/// Étend la zone tactile de [child] jusqu'à [minSize] sans changer sa taille
/// de layout : les touchers hors du cadre mais dans la zone élargie sont
/// ramenés au bord le plus proche avant d'être transmis à l'enfant.
class _ExpandedHitArea extends SingleChildRenderObjectWidget {
  const _ExpandedHitArea({required this.minSize, super.child});

  final double minSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderExpandedHitArea(minSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderExpandedHitArea renderObject,
  ) => renderObject.minSize = minSize;
}

class _RenderExpandedHitArea extends RenderProxyBox {
  _RenderExpandedHitArea(this.minSize);

  double minSize;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final dx = ((minSize - size.width) / 2).clamp(0.0, double.infinity);
    final dy = ((minSize - size.height) / 2).clamp(0.0, double.infinity);
    final zone = Offset.zero & size;
    final expanded = Rect.fromLTRB(
      zone.left - dx,
      zone.top - dy,
      zone.right + dx,
      zone.bottom + dy,
    );
    if (!expanded.contains(position)) return false;
    final clamped = Offset(
      position.dx.clamp(0.0, size.width),
      position.dy.clamp(0.0, size.height),
    );
    // Juste à l'intérieur du bord, pour passer le contrôle `contains`.
    final inside = Offset(
      clamped.dx.clamp(0.0, size.width - 0.01),
      clamped.dy.clamp(0.0, size.height - 0.01),
    );
    return super.hitTest(result, position: inside);
  }
}
