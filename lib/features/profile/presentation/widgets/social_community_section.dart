import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/features/profile/bloc/help_center_bloc.dart';
import 'package:dony/features/profile/data/models/help_center_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SocialCommunitySection extends StatelessWidget {
  const SocialCommunitySection({super.key, required this.links});

  final List<SocialLink> links;

  @override
  Widget build(BuildContext context) {
    final activeLinks = links.where((link) => link.active).toList();
    if (activeLinks.isEmpty) {
      return const SizedBox.shrink();
    }

    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rejoindre la communauté',
          style: tt.titleLarge?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: DonySpacing.xs),
        Text(
          'Retrouve les espaces officiels Yadony.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: DonySpacing.base),
        ...List.generate(activeLinks.length, (index) {
          final link = activeLinks[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == activeLinks.length - 1 ? 0 : DonySpacing.md,
            ),
            child: _SocialCommunityCard(link: link)
                .animate()
                .fadeIn(
                  delay: (index * DonyCurve.staggerMs).ms,
                  duration: DonyDuration.slow,
                  curve: DonyCurve.enter,
                )
                .slideY(
                  begin: 0.04,
                  duration: DonyDuration.slow,
                  curve: DonyCurve.enter,
                ),
          );
        }),
      ],
    );
  }
}

class _SocialCommunityCard extends StatelessWidget {
  const _SocialCommunityCard({required this.link});

  final SocialLink link;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(context, link.network);
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final identity = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: BorderRadius.circular(DonyRadius.md),
          ),
          child: DonyIcon(style.iconAsset, size: 22, color: style.foreground),
        ),
        const SizedBox(width: DonySpacing.md),
        Expanded(
          child: Text(
            style.networkLabel,
            style: tt.titleSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    final actionLabel = Text(
      style.actionLabel,
      style: tt.labelLarge?.copyWith(
        color: style.foreground,
        fontWeight: FontWeight.w700,
      ),
    );
    final action = Row(
      mainAxisSize: largeText ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (largeText) Expanded(child: actionLabel) else actionLabel,
        const SizedBox(width: DonySpacing.xs),
        DonyIcon('arrow-right', size: 18, color: style.foreground),
      ],
    );

    return Semantics(
      button: true,
      label: '${style.actionLabel} ${style.networkLabel}',
      child: ExcludeSemantics(
        child: DonyCard(
          key: Key('help-social-${link.network.name}'),
          onTap: () => context.read<HelpCenterBloc>().add(
            HelpExternalOpenRequested.social(link: link),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: largeText
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identity,
                      const SizedBox(height: DonySpacing.md),
                      action,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: DonySpacing.md),
                      action,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

_SocialStyle _styleFor(BuildContext context, SocialNetwork network) {
  final cs = Theme.of(context).colorScheme;
  final isLight = Theme.of(context).brightness == Brightness.light;

  return switch (network) {
    SocialNetwork.whatsapp => _SocialStyle(
      networkLabel: 'WhatsApp',
      actionLabel: 'Rejoindre',
      iconAsset: 'message-circle',
      foreground: isLight ? DonyColors.success500 : DonyColors.successDark500,
      background: isLight ? DonyColors.success50 : DonyColors.successDark50,
    ),
    SocialNetwork.facebook => _SocialStyle(
      networkLabel: 'Facebook',
      actionLabel: 'Rejoindre',
      iconAsset: 'user-plus',
      foreground: cs.primary,
      background: cs.primaryContainer,
    ),
    SocialNetwork.instagram => _SocialStyle(
      networkLabel: 'Instagram',
      actionLabel: 'Suivre',
      iconAsset: 'camera',
      foreground: cs.secondary,
      background: cs.secondaryContainer,
    ),
    SocialNetwork.tiktok => _SocialStyle(
      networkLabel: 'TikTok',
      actionLabel: 'Suivre',
      iconAsset: 'smartphone',
      foreground: cs.onSurface,
      background: cs.surfaceContainerHighest,
    ),
    SocialNetwork.youtube => _SocialStyle(
      networkLabel: 'YouTube',
      actionLabel: 'S’abonner',
      iconAsset: 'circle-play',
      foreground: cs.error,
      background: cs.errorContainer,
    ),
  };
}

final class _SocialStyle {
  const _SocialStyle({
    required this.networkLabel,
    required this.actionLabel,
    required this.iconAsset,
    required this.foreground,
    required this.background,
  });

  final String networkLabel;
  final String actionLabel;
  final String iconAsset;
  final Color foreground;
  final Color background;
}
