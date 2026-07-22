import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:flutter/material.dart';

/// Bouton favori (signet) — pur visuel, stateless.
///
/// Signet rempli [DonyColors.primary] quand [isFavorite] est vrai, contour
/// [cs.onSurfaceVariant] sinon. Le nom historique du widget est conservé pour
/// ne pas casser ses appelants ; c'est bien un signet qui est rendu.
///
/// Utilise [Icons.bookmark] / [Icons.bookmark_border] (Material) car DonyIcon
/// ne supporte que des SVG mono-tracé sans variante "filled vs outline"
/// distincte pour la même icône.
class FavoriteHeartButton extends StatefulWidget {
  const FavoriteHeartButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 26,
  });

  final bool isFavorite;
  final VoidCallback onToggle;
  final double size;

  @override
  State<FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends State<FavoriteHeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleToggle() {
    _controller.forward(from: 0);
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints(
          minWidth: widget.size + 8,
          minHeight: widget.size + 8,
        ),
        icon: Icon(
          widget.isFavorite ? Icons.bookmark : Icons.bookmark_border,
          color: widget.isFavorite
              ? DonyColors.primary
              : cs.onSurfaceVariant,
          size: widget.size,
        ),
        onPressed: _handleToggle,
        tooltip: widget.isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
      ),
    );
  }
}
