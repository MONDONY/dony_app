import 'package:dony/core/design/design_system.dart';
import 'package:dony/core/widgets/dony_icon.dart';
import 'package:dony/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PendingDeletionBanner extends StatelessWidget {
  final DateTime deletionRequestedAt;
  final VoidCallback onReactivate;

  const PendingDeletionBanner({
    super.key,
    required this.deletionRequestedAt,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = context.l10n;
    final deletionDate = deletionRequestedAt.add(const Duration(days: 30));
    final formattedDate = DateFormat.yMd(l.localeName).format(deletionDate);

    return Container(
      padding: const EdgeInsets.all(DonySpacing.base),
      decoration: BoxDecoration(
        color: cs.errorLight,
        borderRadius: BorderRadius.circular(DonyRadius.card),
        border: Border.all(color: cs.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DonySpacing.sm),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DonyRadius.md),
            ),
            child: DonyIcon('triangle-alert', color: cs.error, size: 18),
          ),
          const SizedBox(width: DonySpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.profileDeletionScheduled(formattedDate),
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onReactivate,
                  child: Text(
                    l.profileDeletionCancelAction,
                    style: tt.bodySmall?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: DonySpacing.xs),
                Text(
                  l.profileDeletionRefundsNotice,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
