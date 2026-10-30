import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Carte du corps d'une fiche (colis, trajet) : petit titre en tête, puis
/// son contenu.
///
/// [trailing] : action courte au bout de la ligne du titre (lien « Voir la
/// liste »). [onTap] : toute la carte est tappable (carte qui mène à un
/// écran), avec l'encre de la carte.
class DetailCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;
  const DetailCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(DonyRadius.card);
    final titleText = Text(
      title,
      style: tt.labelMedium?.copyWith(
        color: cs.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (trailing case final action?)
          Row(
            children: [
              Expanded(child: titleText),
              const SizedBox(width: DonySpacing.sm),
              action,
            ],
          )
        else
          titleText,
        const SizedBox(height: DonySpacing.md),
        child,
      ],
    );
    final tap = onTap;
    if (tap == null) {
      return Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: radius,
          border: Border.all(color: cs.outline),
        ),
        padding: const EdgeInsets.all(DonySpacing.base),
        child: column,
      );
    }
    // Carte tappable : l'encre se dessine sur le `Material`, sous la bordure.
    return Material(
      color: cs.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: tap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: cs.outline),
          ),
          padding: const EdgeInsets.all(DonySpacing.base),
          child: column,
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
