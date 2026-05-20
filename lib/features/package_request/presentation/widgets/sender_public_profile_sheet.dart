import 'package:dony/core/design/design_system.dart';
import 'package:dony/features/package_request/data/models/package_request_search_item.dart';
import 'package:flutter/material.dart';

void showSenderPublicProfileSheet(
  BuildContext context,
  SenderPublicProfile sender,
) {
  DonyBottomSheet.show<void>(
    context,
    title: 'Profil expéditeur',
    child: _SenderPublicProfileContent(sender: sender),
  );
}

class _SenderPublicProfileContent extends StatelessWidget {
  const _SenderPublicProfileContent({required this.sender});

  final SenderPublicProfile sender;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DonySpacing.lg, DonySpacing.md, DonySpacing.lg, DonySpacing.xl,
      ),
      child: Column(
        children: [
          DonyAvatar(
            name: sender.displayName,
            size: DonyAvatarSize.xl,
            verified: sender.kycVerified,
          ),
          const SizedBox(height: DonySpacing.md),
          Text(
            sender.displayName,
            style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          if (sender.kycVerified) ...[
            const SizedBox(height: DonySpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, color: cs.primary, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Identité vérifiée',
                  style: tt.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: DonySpacing.xl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DonySpacing.lg,
              vertical: DonySpacing.md,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DonyRadius.card),
            ),
            child: sender.totalRatings > 0
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_rounded, color: cs.warning, size: 22),
                      const SizedBox(width: DonySpacing.xs),
                      Text(
                        sender.averageRating.toStringAsFixed(1),
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: DonySpacing.sm),
                      Text(
                        '· ${sender.totalRatings} avis',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        color: cs.onSurfaceVariant,
                        size: 18,
                      ),
                      const SizedBox(width: DonySpacing.xs),
                      Text(
                        'Nouveau membre',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
