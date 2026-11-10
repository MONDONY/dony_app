import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/features/video_modal/presentation/widgets/video_modal_frame.dart';
import 'package:dony/features/video_modal/presentation/widgets/video_modal_image.dart';
import 'package:dony/features/video_modal/presentation/widgets/video_modal_sheet.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Bouton touché dans un modal d'information. `null` (geste, retour) n'est
/// pas une réponse : le modal pourra revenir au prochain déclencheur.
///
/// [closed] : la croix des formats carte centrée et plein écran, fermeture
/// explicite qui n'exécute aucune action.
enum InfoModalChoice { primary, secondary, closed }

/// Modal d'une campagne d'information : icône dans un halo (ou bannière),
/// titre, sous-titre, texte (défilable s'il est long) et un ou deux boutons
/// empilés en pleine largeur, principal en haut, fixes en bas. Une affiche
/// remplace tout le contenu.
abstract final class InfoModalSheet {
  static const analyticsName = 'info-modal';

  static Future<InfoModalChoice?> show(
    BuildContext context, {
    required VideoModalCampaign campaign,

    /// Image préchargée ; `null` : modal sans image (bannière en échec).
    VideoModalImage? image,
  }) {
    final poster = image != null && campaign.isPoster;
    return VideoModalFrame.show<InfoModalChoice>(
      context,
      layout: campaign.layout,
      sizePercent: campaign.sizePercent,
      analyticsName: analyticsName,
      poster: poster,
      buttons: InfoModalSheetButtons(campaign: campaign),
      closeResult: InfoModalChoice.closed,
      child: InfoModalSheetContent(campaign: campaign, image: image),
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
  const InfoModalSheetContent({super.key, required this.campaign, this.image});

  final VideoModalCampaign campaign;

  /// Image préchargée de la campagne (`null` : aucune, ou échec du chargement).
  final VideoModalImage? image;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final subtitle = campaign.subtitle;
    final img = image;
    final alt = campaign.imageAlt ?? campaign.title;
    if (img != null && campaign.isPoster) {
      // Affiche : ni titre ni texte, le titre reste le libellé d'accessibilité.
      // Toucher l'affiche vaut le bouton principal.
      void choosePrimary() =>
          Navigator.of(context).pop(InfoModalChoice.primary);
      return Semantics(
        button: true,
        label: alt,
        onTap: choosePrimary,
        excludeSemantics: true,
        child: GestureDetector(
          key: const Key('video-modal-poster-tap'),
          behavior: HitTestBehavior.opaque,
          onTap: choosePrimary,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DonyRadius.lg),
            child: VideoModalPoster(
              image: img,
              fit: campaign.imageFit,
              semanticLabel: alt,
            ),
          ),
        ),
      );
    }
    final banner = img != null && campaign.imageMode == VideoModalImageMode.top;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DonySpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (banner)
            VideoModalBanner(
              image: img,
              fit: campaign.imageFit,
              semanticLabel: alt,
            )
          else
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
