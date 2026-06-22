import 'package:dony/core/design/tokens/color_tokens.dart';
import 'package:flutter/material.dart';

/// Bouton cœur favori — pur visuel, stateless.
///
/// Cœur rempli [DonyColors.favorite] quand [isFavorite] est vrai,
/// contour [cs.onSurfaceVariant] sinon.
///
/// Utilise [Icons.favorite] / [Icons.favorite_border] (Material) car DonyIcon
/// ne supporte que des SVG mono-tracé sans variante "filled vs outline"
/// distincte pour la même icône.
class FavoriteHeartButton extends StatefulWidget {
  const FavoriteHeartButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 22,
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
          minWidth: widget.size + 12,
          minHeight: widget.size + 12,
        ),
        icon: Icon(
          widget.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: widget.isFavorite
              ? DonyColors.favorite
              : cs.onSurfaceVariant,
          size: widget.size,
        ),
        onPressed: _handleToggle,
        tooltip: widget.isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
      ),
    );
  }
}
