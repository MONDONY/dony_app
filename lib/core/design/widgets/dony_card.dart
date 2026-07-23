import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DonyCard extends StatelessWidget {
  const DonyCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.elevated = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  /// Surface « surélevée » : ombre portée + retour tactile au press (léger
  /// enfoncement + atténuation de l'ombre), au lieu de la bordure plate par
  /// défaut. À réserver aux cartes qui doivent se lire comme des objets
  /// cliquables (hub Activités) — le reste de l'app garde la carte plate.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final inner = Padding(
      padding: padding ?? const EdgeInsets.all(DonySpacing.base),
      child: child,
    );

    if (elevated) {
      return _ElevatedDonyCard(onTap: onTap, child: inner);
    }

    if (onTap != null) {
      return Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap!();
          },
          borderRadius: BorderRadius.circular(DonyRadius.card),
          child: inner,
        ),
      );
    }
    return Card(margin: EdgeInsets.zero, child: inner);
  }
}

/// Carte surélevée avec retour tactile.
///
/// L'ombre remplace la bordure plate pour donner de la profondeur ; un fin
/// liseré (`cs.outline`) reste présent pour garder la carte lisible en dark
/// mode, où l'ombre teintée encre porte peu. Au press : léger scale + ombre
/// réduite, interruptible.
class _ElevatedDonyCard extends StatefulWidget {
  const _ElevatedDonyCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_ElevatedDonyCard> createState() => _ElevatedDonyCardState();
}

class _ElevatedDonyCardState extends State<_ElevatedDonyCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(DonyRadius.card);
    const duration = Duration(milliseconds: 120);

    return AnimatedScale(
      scale: _pressed ? 0.975 : 1,
      duration: duration,
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: radius,
          border: Border.all(color: cs.outline.withValues(alpha: 0.6)),
          boxShadow: _pressed ? DonyShadow.xs : DonyShadow.sm,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    widget.onTap!();
                  },
            onHighlightChanged: _setPressed,
            borderRadius: radius,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
