import 'package:dony/core/design/design_system.dart';
import 'package:flutter/material.dart';

/// Card de profil utilisateur (voyageur ou expéditeur).
///
/// Usage :
/// ```dart
/// DonyUserCard(
///   name: 'Ibrahima Diallo',
///   imageUrl: user.photoUrl,
///   subtitle: 'Voyageur • 12 trajets',
///   verified: true,
///   rating: 4.8,
///   onTap: () => context.push('/profile/123'),
/// )
/// ```
class DonyUserCard extends StatelessWidget {
  const DonyUserCard({
    super.key,
    required this.name,
    this.imageUrl,
    this.subtitle,
    this.verified = false,
    this.rating,
    this.trailing,
    this.onTap,
    this.avatarSize = DonyAvatarSize.md,
    this.compact = false,
  });

  final String name;
  final String? imageUrl;
  final String? subtitle;
  final bool verified;
  final double? rating;
  final Widget? trailing;
  final VoidCallback? onTap;
  final DonyAvatarSize avatarSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return DonyCard(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? DonySpacing.md : DonySpacing.base),
      child: Row(
        children: [
          DonyAvatar(
            name: name,
            imageUrl: imageUrl,
            size: avatarSize,
            verified: verified,
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: compact ? tt.titleMedium : tt.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (rating != null) ...[
                      const SizedBox(width: DonySpacing.xs),
                      const Icon(Icons.star_rounded, size: 13, color: DonyColors.warning),
                      const SizedBox(width: DonySpacing.xxs),
                      Text(
                        rating!.toStringAsFixed(1),
                        style: tt.bodySmall?.copyWith(
                          color: DonyColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: DonySpacing.xxs),
                  Text(
                    subtitle!,
                    style: tt.bodySmall?.copyWith(color: DonyColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: DonySpacing.sm),
            trailing!,
          ] else if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: DonyColors.neutral400,
            ),
        ],
      ),
    );
  }
}
