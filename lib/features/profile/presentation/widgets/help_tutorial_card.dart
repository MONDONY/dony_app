import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HelpTutorialCard extends StatelessWidget {
  const HelpTutorialCard({
    super.key,
    required this.tutorial,
    required this.onTap,
  });

  final HelpTutorial tutorial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Semantics(
          button: true,
          label: 'Lire le tutoriel ${tutorial.title}',
          child: ExcludeSemantics(
            child: DonyCard(
              onTap: onTap,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(DonyRadius.card),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DonyImage(
                            url: _thumbnailUrl(tutorial.youtubeVideoId),
                          ),
                          ColoredBox(color: cs.scrim.withValues(alpha: 0.18)),
                          Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: cs.surface.withValues(alpha: 0.94),
                                shape: BoxShape.circle,
                                boxShadow: DonyShadows.sm,
                              ),
                              child: DonyIcon(
                                'circle-play',
                                size: 30,
                                color: cs.primary,
                              ),
                            ),
                          ),
                          if (tutorial.durationLabel case final duration?)
                            Positioned(
                              right: DonySpacing.sm,
                              bottom: DonySpacing.sm,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DonySpacing.sm,
                                  vertical: DonySpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.inverseSurface.withValues(
                                    alpha: 0.9,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    DonyRadius.sm,
                                  ),
                                ),
                                child: Text(
                                  duration,
                                  style: tt.labelMedium?.copyWith(
                                    color: cs.onInverseSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(DonySpacing.base),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tutorial.title,
                          style: tt.titleSmall?.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: DonySpacing.xs),
                        Text(
                          tutorial.description,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: DonyDuration.slow, curve: DonyCurve.enter)
        .slideY(
          begin: 0.04,
          duration: DonyDuration.slow,
          curve: DonyCurve.enter,
        );
  }
}

String _thumbnailUrl(String videoId) {
  return Uri.https('i.ytimg.com', '/vi/$videoId/hqdefault.jpg').toString();
}
