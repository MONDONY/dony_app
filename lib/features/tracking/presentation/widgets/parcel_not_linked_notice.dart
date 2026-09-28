import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Colis refusé par le back (403) : ni expéditeur ni voyageur, l'utilisateur
/// ne peut pas le suivre ici. Refus définitif, donc pas de « Réessayer ».
class ParcelNotLinkedNotice extends StatelessWidget {
  const ParcelNotLinkedNotice({super.key, this.centered = false});

  /// Centré dans la feuille du parcours, aligné à gauche sous un champ.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final align = centered ? TextAlign.center : TextAlign.start;
    return Column(
      key: const Key('parcel-not-linked'),
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (centered) ...[
          DonyIcon('lock', size: 32, color: cs.onSurfaceVariant),
          const SizedBox(height: DonySpacing.md),
        ],
        Text(
          l.trackingNotLinkedTitle,
          textAlign: align,
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          l.trackingNotLinkedBody,
          textAlign: align,
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
