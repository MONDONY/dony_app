import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Les deux réponses à « Vous voyagez en tant que ? » : Particulier ou GP Pro.
///
/// Deux cartes à toucher, sans clavier ni présélection. Sous « Particulier »,
/// la phrase par laquelle le voyageur confirme voyager à titre personnel : la
/// confirmation envoyée au back est ce texte lu, plus une case à cocher.
///
/// Partagé par la feuille de la publication ([TravelerStatusSheet]) et par
/// l'écran de blocage (limite mensuelle atteinte). [busy] grise les deux
/// cartes pendant l'envoi.
class TravelerStatusChoiceTiles extends StatelessWidget {
  const TravelerStatusChoiceTiles({
    required this.onIndividual,
    required this.onGpPro,
    this.busy = false,
    super.key,
  });

  final VoidCallback onIndividual;
  final VoidCallback onGpPro;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChoiceTile(
          tileKey: const Key('traveler-status-individual'),
          title: l.travelerStatusOptionIndividual,
          body: l.travelerStatusOptionIndividualBody,
          onTap: busy ? null : onIndividual,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DonySpacing.xs,
            DonySpacing.xs,
            DonySpacing.xs,
            0,
          ),
          child: Text(
            l.travelerStatusIndividualConfirmation,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: DonySpacing.md),
        _ChoiceTile(
          tileKey: const Key('traveler-status-gp-pro'),
          title: l.travelerStatusOptionGpPro,
          body: l.travelerStatusOptionGpProBody,
          onTap: busy ? null : onGpPro,
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.tileKey,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final Key tileKey;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: onTap != null,
      container: true,
      excludeSemantics: true,
      // Titre et explication sont déjà traduits : simplement juxtaposés.
      label: '$title, $body',
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: InkWell(
          key: tileKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(DonyRadius.card),
          child: Container(
            padding: const EdgeInsets.all(DonySpacing.base),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(DonyRadius.card),
              border: Border.all(color: cs.outline, width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: DonySpacing.xxs),
                      Text(
                        body,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                DonyIcon('chevron-right', color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
