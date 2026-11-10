import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/video_modal/data/models/video_modal_campaign.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Réponse de la personne au modal. `null` (geste, retour) n'est pas une
/// réponse : le modal pourra revenir au prochain déclencheur.
enum VideoModalChoice { watch, dismiss }

/// Feuille du bas d'une campagne : icône dans un halo, titre, sous-titre,
/// miniature de la vidéo avec sa durée, jusqu'à trois points forts, et deux
/// boutons empilés en pleine largeur dans le pied collant.
abstract final class VideoModalSheet {
  static const analyticsName = 'video-modal';

  static Future<VideoModalChoice?> show(
    BuildContext context, {
    required VideoModalCampaign campaign,
  }) {
    return DonyBottomSheet.show<VideoModalChoice>(
      context,
      analyticsName: analyticsName,
      stickyBottom: VideoModalSheetButtons(campaign: campaign),
      child: VideoModalSheetContent(campaign: campaign),
    );
  }
}

/// Les deux boutons du pied collant, principal en haut.
class VideoModalSheetButtons extends StatelessWidget {
  const VideoModalSheetButtons({super.key, required this.campaign});

  final VideoModalCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DonyButton(
          key: const Key('video-modal-primary'),
          label: campaign.primaryLabel ?? l.videoModalPrimaryFallback,
          iconAsset: 'circle-play',
          onPressed: () => Navigator.of(context).pop(VideoModalChoice.watch),
        ),
        const SizedBox(height: DonySpacing.sm),
        DonyButton(
          key: const Key('video-modal-secondary'),
          label: campaign.secondaryLabel ?? l.videoModalSecondaryFallback,
          variant: DonyButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(VideoModalChoice.dismiss),
        ),
      ],
    );
  }
}

class VideoModalSheetContent extends StatelessWidget {
  const VideoModalSheetContent({super.key, required this.campaign});

  final VideoModalCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
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
                Icons.smart_display_rounded,
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
          _Thumbnail(campaign: campaign),
          if (campaign.highlights.isNotEmpty) ...[
            const SizedBox(height: DonySpacing.base),
            Text(
              l.videoModalHighlightsTitle,
              textAlign: TextAlign.center,
              style: tt.titleSmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: DonySpacing.sm),
            for (final h in campaign.highlights) _HighlightRow(highlight: h),
          ],
          const SizedBox(height: DonySpacing.sm),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.campaign});

  final VideoModalCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final duration = campaign.durationLabel;
    return Semantics(
      button: true,
      label: context.l10n.videoModalThumbnailSemantics(campaign.title),
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('video-modal-thumbnail'),
        onTap: () => Navigator.of(context).pop(VideoModalChoice.watch),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(DonyRadius.lg),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: DonyColors.ink800),
                Image.network(
                  'https://i.ytimg.com/vi/${campaign.youtubeVideoId}/hqdefault.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 32,
                      color: DonyColors.ink800,
                    ),
                  ),
                ),
                if (duration != null)
                  Positioned(
                    right: DonySpacing.sm,
                    bottom: DonySpacing.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DonySpacing.sm,
                        vertical: DonySpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(DonyRadius.sm),
                      ),
                      child: Text(
                        duration,
                        style: tt.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.highlight});

  final VideoModalHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: DonySpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(DonySpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DonyRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(DonyRadius.md),
              ),
              child: Icon(
                videoModalIconData(highlight.icon),
                size: 20,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: DonySpacing.md),
            Expanded(
              child: Text(
                highlight.text,
                style: tt.bodyMedium?.copyWith(color: cs.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icône Material d'un point fort (jamais de camion : voir CLAUDE.md).
IconData videoModalIconData(VideoModalIcon icon) => switch (icon) {
  VideoModalIcon.parcel => Icons.inventory_2_rounded,
  VideoModalIcon.suitcase => Icons.luggage_rounded,
  VideoModalIcon.lock => Icons.lock_rounded,
  VideoModalIcon.search => Icons.search_rounded,
  VideoModalIcon.chat => Icons.chat_bubble_rounded,
  VideoModalIcon.qr => Icons.qr_code_2_rounded,
  VideoModalIcon.star => Icons.star_rounded,
  VideoModalIcon.wallet => Icons.account_balance_wallet_rounded,
  VideoModalIcon.bell => Icons.notifications_rounded,
  VideoModalIcon.info => Icons.info_rounded,
};
