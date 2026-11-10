import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/presentation/widgets/video_modal_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Bouton touché dans un modal d'information. `null` (geste, retour) n'est
/// pas une réponse : le modal pourra revenir au prochain déclencheur.
enum InfoModalChoice { primary, secondary }

/// Feuille du bas d'une campagne d'information : icône dans un halo, titre,
/// sous-titre, texte (défilable s'il est long) et un ou deux boutons empilés
/// en pleine largeur dans le pied collant, principal en haut.
abstract final class InfoModalSheet {
  static const analyticsName = 'info-modal';

  static Future<InfoModalChoice?> show(
    BuildContext context, {
    required VideoModalCampaign campaign,
  }) {
    return DonyBottomSheet.show<InfoModalChoice>(
      context,
      analyticsName: analyticsName,
      stickyBottom: InfoModalSheetButtons(campaign: campaign),
      child: InfoModalSheetContent(campaign: campaign),
    );
  }
}

String _fallbackLabel(BuildContext context, VideoModalAction? action) {
  final l = context.l10n;
  return action?.kind == VideoModalActionKind.close
      ? l.infoModalCloseFallback
      : l.infoModalOpenFallback;
}

/// Les boutons du pied collant : un seul, ou deux empilés.
class InfoModalSheetButtons extends StatelessWidget {
  const InfoModalSheetButtons({super.key, required this.campaign});

  final VideoModalCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final secondary = campaign.secondaryAction;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyButton(
          key: const Key('info-modal-primary'),
          label:
              campaign.primaryLabel ??
              _fallbackLabel(context, campaign.primaryAction),
          onPressed: () => Navigator.of(context).pop(InfoModalChoice.primary),
        ),
        if (secondary != null) ...[
          const SizedBox(height: DonySpacing.sm),
          DonyButton(
            key: const Key('info-modal-secondary'),
            label:
                campaign.secondaryLabel ?? _fallbackLabel(context, secondary),
            variant: DonyButtonVariant.secondary,
            onPressed: () =>
                Navigator.of(context).pop(InfoModalChoice.secondary),
          ),
        ],
      ],
    );
  }
}

class InfoModalSheetContent extends StatelessWidget {
  const InfoModalSheetContent({super.key, required this.campaign});

  final VideoModalCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final subtitle = campaign.subtitle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                videoModalIconData(campaign.icon ?? VideoModalIcon.info),
                key: const Key('info-modal-icon'),
                size: 34,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            campaign.title,
            textAlign: TextAlign.center,
            style: tt.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: DonySpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: DonySpacing.base),
          Text(
            campaign.body ?? '',
            key: const Key('info-modal-body'),
            textAlign: TextAlign.center,
            style: tt.bodyLarge?.copyWith(color: cs.onSurface, height: 1.4),
          ),
          const SizedBox(height: DonySpacing.sm),
        ],
      ),
    );
  }
}
